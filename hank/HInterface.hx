package hank;

import hscript.Parser;
import hscript.Interp;
import hscript.Expr;

import hank.Story;


/**
 Interface between a Hank story, and its embedded hscript interpreter
**/
@:allow(tests.HInterfaceTest)
class HInterface {
    var BOOLEAN_OPS = ['&&', '||', '!'];
    var story: Story;

    var parser: Parser = new Parser();
    var interp: Interp = new Interp();

    public function new(story: Story) {
        this.story = story;
        interp.variables['story'] = story;

        // TODO allow constructing the interface with external state variables. These variables should all be serializable so stories can be deterministically replayed
        // TODO although... that excludes something like FlxG. Maybe 2 different pipelines for passing in Haxe objects, one serializable and one not.

    }


    /**
     Run a pre-processed block of Haxe embedded in a Hank story.
    **/
    public function runEmbeddedHaxe(haxe: String) {
        var expr = parser.parseString(haxe);
        expr = transmute(expr);
        interp.execute(expr);
    }

    /**
     Convert numerical value expressions to booleans for binary operations
    **/
    function boolify(expr: Expr): Expr {
        // TODO this may work but it is not well-thought-out and may have unintended consequences
        return EBinop('>', expr, EConst(CInt(0)));
    }

    /**
     Adapt an expression for the embedded context
    **/
    function transmute(expr: Expr) {
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