package hank;

import haxe.macro.Expr;
import haxe.macro.Context;

class DebugMacros {
    public static macro function watch(e: Expr): Expr {
        switch (e.expr) {
            case EConst(CIdent(i)):
                return macro trace('$i:' + $e);
            default:
                throw 'Can only watch variables (for now)';
        }
    }
}