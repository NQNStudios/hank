package hank;

using Reflect;
using Type;

import hscript.Parser;
import hscript.Interp;
import hscript.Expr;

import hank.StoryTree;

/**
 Interface between a Hank story, and its embedded hscript interpreter
**/
@:allow(tests.HInterfaceTest)
class HInterface {
    var BOOLEAN_OPS = ['&&', '||', '!'];

    var parser: Parser = new Parser();
    var interp: Interp = new Interp();
    var viewCounts: Map<StoryNode, Int>;

    public function new(storyTree: StoryNode, viewCounts: Map<StoryNode, Int>) {
        this.interp.variables['_isTruthy'] = isTruthy;
        this.interp.variables['_resolve'] = resolve.bind(this.interp.variables, storyTree);
        this.interp.variables['_resolveField'] = resolve.bind(this.interp.variables);
        this.viewCounts = viewCounts;
    }

    static function isStoryNode(o: Dynamic) {
        var type = o.typeof();
        switch (type) {
            case TClass(c):
                if (c.getClassName() == 'hank.StoryNode') {
                    return true;
                }
            default:
        }
        return false;
    }

    static function resolve(variables: Map<String, Dynamic>, container: Dynamic, name: String): Dynamic {
        if (variables.exists(name)) {
            return variables[name];
        } else if (isStoryNode(container)) {
            // If the variable is a StoryNode, don't return the node, return its viewCount
            var node: StoryNode = cast(container, StoryNode);
            switch (node.resolve(name)) {
                case Some(node):
                    return node;
                case None:
                    throw 'Cannot resolve ${name}';
            }
        }
        else {
            return container.field(name);
        }
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
        var expr = parser.parseString(h);
        expr = transmute(expr);
        interp.execute(expr);
    }

    public function evaluateExpr(h: String): String {
        var expr = parser.parseString(h);
        expr = transmute(expr);
        var val = interp.expr(expr);

        return Std.string(if (val == null) {
            throw 'Expression ${h} evaluated to null';
        } else if (isStoryNode(val)) {
            var node: StoryNode = cast(val, StoryNode);
            viewCounts[node];
        } else {
            val;
        });
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
                // Identifiers need to be resolved
                ECall(EIdent('_resolve'), [EConst(CString(name))]);
            case EVar(name, _, nested):
                // Declare all variables in embedded global context
                interp.variables[name] = null;
                EBinop('=', EIdent(name), transmute(nested));
            case EParent(nested):
                EParent(transmute(nested));
            case EBlock(nestedExpressions):
                EBlock([for(nested in nestedExpressions) transmute(nested)]);
            case EField(nested, f):
                ECall(EIdent('_resolveField'), [transmute(nested), EConst(CString(f))]);
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
                // To provide for the {if(cond) 'something'} idiom, give every if statement an else clause returning an empty string.
                if (e2 == null) {
                    e2 = EConst(CString(''));
                }
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