package hank;

import haxe.ds.Option;

enum OutputType {
    Text(t: String); // Pure text that is always displayed
    // Alt(a: Alt); // TODO re-implement Alts recursively. Each alt branch should be an Output
    HExpression(h: String); // An embedded Haxe expression whose value will be inserted
    InlineDivert(t: String); // A divert statement on the same line as an output sequence.
    InlineComment(c: String); // A block comment in the middle of an output sequence
    ToggleOutput(o: Output); // Output that will sometimes be displayed (i.e. [bracketed] section in a choice text)
}

typedef Output = Array<OutputType>;

enum ExprType {
    EIncludeFile(path: String);
    EOutput(output: Output);
    EDivert(target: String);
    EKnot(name: String);
    EStitch(name: String);
    EComment(message: String);
    ENoOp;
    EHaxeLine(haxe: String);
}

typedef HankExpr = {
    var position: FileBuffer.Position;
    var expr: ExprType;
}

typedef HankAST = Array<HankExpr>;

@:allow(tests.ParserTest)
class Parser {
    var symbols = [
        'INCLUDE ' => include,
        '//' => lineComment,
        '/*' => blockComment,
        '->' => divert,
        '===' => knot,
        '==' => knot,
        '=' => stitch,
        '~' => haxeLine
    ];

    var buffers: Array<FileBuffer> = [];
    var ast: HankAST = [];

    public function new() {

    }

    public function parseFile(f: String, includedFile = false) : HankAST {
        var directory = '';
        var lastSlashIdx = f.lastIndexOf('/');
        if (lastSlashIdx != -1) {
            directory = f.substr(0, lastSlashIdx+1);
            f = f.substr(lastSlashIdx+1);
        }

        buffers.insert(0, new FileBuffer(directory + f));

        while (true) {
            var position = buffers[0].position();
            var nextLine = buffers[0].takeLine('lr');
            switch (nextLine) {
                case Some(line):
                    var expr = parseLine(line, buffers[0], position);
                    switch (expr) {
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
                case None:
                    break;
            }
        } 

        var parsedAST = ast;

        // If we just finished parsing a top-level file, clear the AST so the parser can be reused
        if (!includedFile) {
            ast = [];
        }

        buffers.remove(buffers[0]);

        return parsedAST;
    }

    function parseLine(line: String, restOfBuffer: FileBuffer, position: FileBuffer.Position) : ExprType {
        if (StringTools.trim(line).length == 0) {
            return ENoOp;
        }

        for (symbol in symbols.keys()) {
            if (StringTools.startsWith(line, symbol)) {
                return symbols[symbol](line, restOfBuffer, position);
            }
        }

        return output(line, buffers[0], position);
    }

    /** Split the given line into n tokens, throwing an error if there are any number of tokens other than n **/
    static function lineTokens(line:String, n: Int, position: FileBuffer.Position) {
        var tokens = line.split(' ');
        if (tokens.length != n) {
            throw 'Include file error at ${position}: ${tokens.length} tokens provided--should be ${n}.\nLine: `${line}`';
        }
        return tokens;
    }

    static function lineComment(line: String, rob: FileBuffer, position: FileBuffer.Position) : ExprType {
        return EComment(StringTools.trim(line.substr(2)));
    }

    static function blockComment(line: String, rob: FileBuffer, position: FileBuffer.Position) : ExprType {
        var text = line.substr(2);
        rob.give(text + '\n');

        var nesting = 1;
        var endIdx = -1;

        while (nesting > 0) {
            var nextCommentTerminator = rob.peekWhichComesNext(['/*', '*/']);
            switch (nextCommentTerminator) {
                case Some([0, index]):
                    nesting += 1;
                case Some([1, index]):
                    nesting -= 1;
                    endIdx = index;
                case None:
                    throw 'Block comment starting at ${position} never terminates!';
            }
        }

        text = rob.take(endIdx);
        rob.drop('*/');
        return EComment(StringTools.trim(text));
    }

    static function include(line: String, rob: FileBuffer, position: FileBuffer.Position) : ExprType {
        var tokens = lineTokens(line, 2, position);
        return EIncludeFile(tokens[1]);
    }

    static function divert(line: String, rob: FileBuffer, position: FileBuffer.Position) : ExprType {
        var tokens = lineTokens(line, 2, position);
        return EDivert("tokens[1]");
    }

    static function output(line: String, rob: FileBuffer, position: FileBuffer.Position) : ExprType {
    }

    static function knot(line: String, rob: FileBuffer, position: FileBuffer.Position) : ExprType {
        var tokens = lineTokens(line, 2, position);
        return EKnot(tokens[1]);
    }

    static function stitch(line: String, rob: FileBuffer, position: FileBuffer.Position) : ExprType {
        var tokens = lineTokens(line, 2, position);
        return EStitch("tokens[1]");
    }

    static function haxeLine(line: String, rob: FileBuffer, position: FileBuffer.Position) : ExprType {
        return EHaxeLine(StringTools.trim(line.substr(1)));
    }

}