package hank;

import haxe.ds.Option;

enum OutputType {
    Text(t: String); // Pure text that is always displayed
    HExpression(h: String); // An embedded Haxe expression whose value will be inserted
    ToggleOutput(o: Output); // Output that will sometime be displayed (i.e. [bracketed] section in a choice text)
}

typedef Output = Array<OutputType>;

enum ExprType {
    EIncludeFile(path: String);
    EOutput(o: Output);
    EDivert(target: String);
    ENoOp;
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
        '->' => divert,
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
                    var expr = parseLine(line, position);
                    switch (expr) {
                        case EIncludeFile(file):
                            parseFile(directory + file, true);
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

    function parseLine(line: String, position: FileBuffer.Position) : ExprType {
        if (StringTools.trim(line).length == 0) {
            return ENoOp;
        }
        for (symbol in symbols.keys()) {
            if (StringTools.startsWith(line, symbol)) {
                return symbols[symbol](line, position);
            }
        }

        return output(line, position);
    }

    static function include(line: String, position: FileBuffer.Position) : ExprType {
        var tokens = line.split(' ');
        if (tokens.length != 2) {
            throw 'Include file error at ${position}: ${tokens.length} tokens provided--should be 2.';
        }

        var file = tokens[1];
            return EIncludeFile(file);
    }

    static function divert(line: String, position: FileBuffer.Position) : ExprType {
        return EDivert("");
    }

    static function output(line: String, position: FileBuffer.Position) : ExprType {
        return EOutput([Text("")]);
    }

}