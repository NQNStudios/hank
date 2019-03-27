package hank;

using Extensions.OptionExtender;
import hank.HankAST.ExprType;

/**
 Parses Hank scripts into ASTs for a Story object to interpret. Additional parsing happens in Alt.hx and Output.hx
**/
@:allow(tests.ParserTest)
class Parser {
    static var symbols: Array<Map<String, HankBuffer -> HankBuffer.Position -> ExprType>> = [
        ['INCLUDE ' => include],
        ['->' => divert],
        ['===' => knot],
        ['==' => knot],
        ['=' => stitch],
        ['~' => haxeLine],
        ['```' => haxeBlock],
        ['-' => gather],
        ['*' => choice],
        ['+' => choice]
    ];

    var buffers: Array<HankBuffer> = [];
    var ast: HankAST = [];

    public function new() {
        choices = 0;
    }

    public function parseString(h: String): HankAST {
        var stringBuffer = HankBuffer.Dummy(h);

        var parsedAST = [];
        do {
            var position = stringBuffer.position();
            stringBuffer.skipWhitespace();
            if (stringBuffer.isEmpty()) break;
            var expr = parseExpr(stringBuffer, position);
            switch(expr) {
                case EIncludeFile(file):
                    throw 'cannot include files from within an embedded Hank block';
                case ENoOp:
                    // Drop no-ops from the AST
                default:
                    parsedAST.push({
                        position: position,
                        expr: expr
                        });
            }
        } while (!stringBuffer.isEmpty());

        return parsedAST;
    }

    public function parseFile(f: String, includedFile = false) : HankAST {
        var directory = '';
        var lastSlashIdx = f.lastIndexOf('/');
        if (lastSlashIdx != -1) {
            directory = f.substr(0, lastSlashIdx+1);
            f = f.substr(lastSlashIdx+1);
        }

        buffers.insert(0, HankBuffer.FromFile(directory + f));

        while (buffers.length > 0) {
            var position = buffers[0].position();
            buffers[0].skipWhitespace();
            if (buffers[0].isEmpty()) {
                buffers.remove(buffers[0]);
            } else {
                var expr = parseExpr(buffers[0], position);
                switch(expr) {
                    case EIncludeFile(file):
                        parseFile(directory + file, true);
                    case ENoOp:
                        // Drop no-ops from the AST
                    default:
                        ast.push({
                            position: position,
                            expr: expr
                            });
                }
            }
        }

        var parsedAST = ast;

        // If we just finished parsing a top-level file, clear the AST so the parser can be reused
        if (!includedFile) {
            ast = [];
        }

        return parsedAST;
    }

    static function parseExpr(buffer: HankBuffer, position: HankBuffer.Position) : ExprType {
        var line = buffer.peekLine();
        switch (line) {
            case None:
                throw 'Tried to parse expr when no lines were left in file';
            case Some(line):
                if (StringTools.trim(line).length == 0) {
                    return ENoOp;
                }

                for (rule in symbols) {
                    var symbol = rule.keys().next();
                    var rule = rule[symbol];
                    if (StringTools.startsWith(line, symbol)) {
                        return rule(buffer, position);
                    }
                }

                return output(buffer, position);
        }

    }

    /** Split the given line into n tokens, throwing an error if there are any number of tokens other than n **/
    static function lineTokens(buffer: HankBuffer, n: Int, position: HankBuffer.Position): Array<String> {
        var line = buffer.takeLine().unwrap();
        var tokens = line.split(' ');
        if (tokens.length != n) {
            throw 'Include file error at ${position}: ${tokens.length} tokens provided--should be ${n}.\nLine: `${line}`';
        }
        return tokens;
    }

    static function include(buffer: HankBuffer, position: HankBuffer.Position) : ExprType {
        var tokens = lineTokens(buffer, 2, position);
        return EIncludeFile(tokens[1]);
    }

    static function divert(buffer: HankBuffer, position: HankBuffer.Position) : ExprType {
        buffer.drop('->');
        buffer.skipWhitespace();
        var tokens = lineTokens(buffer, 1, position);
        return EDivert(tokens[0]);
    }

    static function output(buffer: HankBuffer, position: HankBuffer.Position) : ExprType {
        return EOutput(Output.parse(buffer));
    }

    static function knot(buffer: HankBuffer, position: HankBuffer.Position) : ExprType {
        buffer.drop('==');
        if (buffer.peekAhead(0, 1) == '=')
        {
            buffer.drop('=');
        }
        buffer.skipWhitespace();
        var tokens = lineTokens(buffer, 1, position);
        return EKnot(tokens[0]);
    }

    static function stitch(buffer: HankBuffer, position: HankBuffer.Position) : ExprType {
        buffer.drop('=');
        buffer.skipWhitespace();
        var tokens = lineTokens(buffer, 1, position);
        return EStitch(tokens[0]);
    }

    static function haxeLine(buffer: HankBuffer, position: HankBuffer.Position) : ExprType {
        buffer.drop('~');
        return EHaxeLine(buffer.takeLine('lr').unwrap());
    }

    static function gather(buffer: HankBuffer, position: HankBuffer.Position) : ExprType {
        var depth = buffer.countConsecutive('-');
        buffer.skipWhitespace();
        var label = buffer.expressionIfNext('(', ')');
        buffer.skipWhitespace();
        return EGather(label, depth, parseExpr(buffer, buffer.position()));
    }

    static var choices: Int = 0;
    
    static function choice(buffer: HankBuffer, position: HankBuffer.Position): ExprType {
        var symbol = buffer.peek(1);
        var onceOnly = symbol == '*';
        var depth = buffer.countConsecutive(symbol);
        buffer.skipWhitespace();
        var label = buffer.expressionIfNext('(', ')');
        buffer.skipWhitespace();
        var condition = buffer.expressionIfNext('{','}');
        buffer.skipWhitespace();
        var output = Output.parse(buffer);
        var divertTarget = output.takeInlineDivert();

        return EChoice(choices++, onceOnly, label, condition, depth, output, divertTarget);
    }

    static function haxeBlock(buffer: HankBuffer, position: HankBuffer.Position): ExprType {
        buffer.drop('```\n');
        var rawContents = buffer.takeUntil(['```'], false, true).unwrap().output;
        var processedContents = '';

        var blockBuffer = HankBuffer.Dummy(rawContents);

        // Transform , and ,,, expressions into Hank embedded in Haxe embedded in Hank
        do {
            var nextLine = blockBuffer.takeLine('lr').unwrap();
            if (nextLine == ',,,'){
                var embeddedHankBlock = blockBuffer.takeUntil([',,,'],false,true).unwrap().output;
                processedContents += 'story.runEmbeddedHank("${escapeQuotes(embeddedHankBlock)}"); ';
            } else if (StringTools.startsWith(nextLine, ',')) {
                nextLine = StringTools.trim(nextLine.substr(1));
                processedContents += 'story.runEmbeddedHank("${escapeQuotes(nextLine)}"); ';
            } else {
                processedContents += nextLine+' ';
            }
        } while (!blockBuffer.isEmpty());

        return EHaxeBlock(processedContents);
    }

    static function escapeQuotes(s: String) {
        var escaped = s;
        escaped = StringTools.replace(escaped, "'", "\\'");
        escaped = StringTools.replace(escaped, '"', '\\"');
        return escaped;
    }
}