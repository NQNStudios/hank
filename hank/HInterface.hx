package hank;

import hscript.Parser;
import hscript.Interp;
import hscript.Expr;

/**
 Interface between a Hank story, and its embedded hscript interpreter
**/
@:allow(tests.HInterfaceTest)
class HInterface {
    var BOOLEAN_OPS = ['&&', '||', '!'];

    var parser: Parser = new Parser();
    var interp: Interp = new Interp();
    var viewCounts: ViewCounts;

    public function new(viewCounts: ViewCounts) {
        this.viewCounts = viewCounts;

        this.interp.variables['_isTruthy'] = isTruthy;
    }

    static function isTruthy(v: Dynamic) {
        switch (Type.typeof(v)) {
            case TBool:
                return v;
            case TInt | TFloat:
                return v > 0;
            default:
                throw '$v cannot be coerced to a boolean';
        }
    }

    public function addVariable(identifier: String, value: Dynamic) {
        this.interp.variables[identifier] = value;
    }

    /**
     Run a pre-processed block of Haxe embedded in a Hank story.
    **/
    public function runEmbeddedHaxe(h: String) {
        trace(h);
        var expr = parser.parseString(h);
        expr = transmute(expr);
        interp.execute(expr);
    }

    public function evaluateExpr(h: String): String {
        var expr = parser.parseString(h);
        trace(expr);
        expr = transmute(expr);
        var val = interp.expr(expr);
        if (val == null) {
            return '';
        } else {
            return Std.string(val);
        }
    }

    public function resolve(identifier: String, scope: String): Dynamic {
        if (interp.variables.exists(identifier)) {
            return interp.variables[identifier];
        } else {
            return viewCounts.resolve(identifier, scope);
        }
    }

    /**
     Convert numerical value expressions to booleans for binary operations
    **/
    function boolify(expr: Expr): Expr {
        return ECall(EIdent('_isTruthy'), [expr]);
    }

    /**
     Adapt an expression for the embedded context
    **/
    function transmute(expr: Expr) {
        if (expr == null) {
            return null;
        }
        return switch (expr) {
            case EIdent(name):
                // TODO if the name is a root-level view count, return EArray(view_counts, ...)
                // Or if it's a nested view count of the current scope, also need to resolve that
                EIdent(name);
            case EVar(name, _, nested):
                // Declare all variables in embedded global context
                interp.variables[name] = null;
                EBinop('=', EIdent(name), transmute(nested));
            case EParent(nested):
                EParent(transmute(nested));
            case EBlock(nestedExpressions):
                EBlock([for(nested in nestedExpressions) transmute(nested)]);
            case EField(nested, f):
                // TODO this is where . access on view counts will be handled by transmuting to an EArray
                EField(transmute(nested), f);
            case EBinop(op, e1, e2):
                if (BOOLEAN_OPS.indexOf(op) != -1) {
                    EBinop(op, boolify(e1), boolify(e2));
                } else {
                    expr;
                }
            case EUnop(op, prefix, e):
                if (BOOLEAN_OPS.indexOf(op) != -1) {
                    EUnop(op, prefix, boolify(e));
                } else {
                    expr;
                }
            case ECall(e, params):
                ECall(transmute(e), [for (ex in params) transmute(ex)]);
            case EIf(cond, e1, e2):
                EIf(boolify(cond), transmute(e1), transmute(e2));
            case EWhile(cond, e):
                EWhile(boolify(cond), transmute(e));
            case EFor(v, it, e):
                EFor(v, transmute(it), transmute(e));
            case EFunction(args, e, name, ret):
                EFunction(args, transmute(e), name, ret);
            case EReturn(e):
                EReturn(transmute(e));
            case EArray(e, index):
                EArray(transmute(e), transmute(index));
            case EArrayDecl(e):
                EArrayDecl([for (ex in e) transmute(ex)]);
            case ENew(cl, params):
                ENew(cl, [for (ex in params) transmute(ex)]);
            case EThrow(e):
                EThrow(transmute(e));
            case ETry(e, v, t, ecatch):
                ETry(transmute(e), v, t, transmute(ecatch));
            case EObject(fl):
                EObject([for (pair in fl) { name: pair.name, e: transmute(pair.e)}]);
            case ETernary(cond, e1, e2):
                ETernary(boolify(cond), transmute(e1), transmute(e2));
            case ESwitch( e, cases, defaultExpr):
                ESwitch(transmute(e), [for (arm in cases) { values: [for (value in arm.values) transmute(value)], expr: transmute(arm.expr)}], transmute(defaultExpr));
            case EDoWhile(cond, e):
                EDoWhile(boolify(cond), transmute(e));
            case EMeta(name, args, e):
                EMeta(name, [for (arg in args) transmute(arg)], transmute(e));
            case ECheckType(e, t):
                ECheckType(transmute(e), t);
            default:
                expr;
        }
    }
    
}