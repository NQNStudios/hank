package hank;

import haxe.ds.Option;

enum ExprType {
    EIncludeFile(path: String);

    EOutput(o: Output);

    EDivert(target: String);
    EKnot(name: String);
    EStitch(name: String);
    ENoOp;
    EHaxeLine(haxe: String);

    EHaxeBlock(haxe: String);
    EGather(label: Option<String>, depth: Int, expr: ExprType);
    // Choices are the most complicated expressions 
    EChoice(id: Int, onceOnly: Bool, label: Option<String>, condition: Option<String>, depth: Int, output: Output, divertTarget: Option<String>);
}

typedef HankExpr = {
    var position: HankBuffer.Position;
    var expr: ExprType;
}

typedef HankAST = Array<HankExpr>;

/**
 Implements helper functions for navigating a Hank AST.
**/
class ASTExtension {
    public static function findFile(ast: HankAST, path: String) {
        for (i in 0... ast.length) {
            var expr = ast[i];
            if (expr.position.file == path) {
                return i;
            }
        }

        return -1;
    }
}