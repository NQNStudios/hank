package hank;

using Reflect;
using Type;
import haxe.ds.Option;

import hscript.Parser;
import hscript.Interp;
import hscript.Expr;

using hank.Extensions;
import hank.StoryTree;
import hank.Story;

class HankInterp extends Interp {
  var hInterface: HInterface;
  var story: Story;
  public function setStory(story: Story) {
    this.story = story;
  }
  public function new(hInterface: HInterface) {
    this.hInterface = hInterface;
    super();
  }
  public override function expr(e: Expr): Dynamic {
    switch (e) {
      // pointers are actually just string keys to the Interp's variables.

    case EUnop("&", true, e):
      switch (e) {
      case EIdent(id):
	return id;
      default:
	throw 'Addressing complex expressions is not implemented';
      }
    case EUnop("*", true, e):
      switch (e) {
      case EIdent(id):
	return variables[variables[id]];
      default:
	throw 'Dereferencing complex expressions is not implemented';
      }
      // TODO Divert target variables are just StoryNode values
    case EUnop("->", true, e):
      // trace(e);
      var targetWithDots = '';
      var trailingDot = false;
      while (true) {
      switch (e) {
      case EIdent(lastTarget):
	targetWithDots = lastTarget + '.' + targetWithDots;
	if (trailingDot) targetWithDots = targetWithDots.substr(0,targetWithDots.length-1);
	// trace('final target is $targetWithDots');
	var node = story.resolveNodeInScope(targetWithDots);
					    trace (node);
					    return node;
      case EField(eNested, lastTarget):
	targetWithDots = lastTarget + '.' + targetWithDots;

	trailingDot = true;
	e = eNested;
      default: throw 'Divert target variable cannot be specified in form $e';
      }
      }
      
    default: return super.expr(e);
    }
    
  }

  override function assign(e1: Expr, e2: Expr): Dynamic {
    var v = expr(e2);
    switch (e1) {
    case EUnop("*", true, e):
      switch (e) {
      case EIdent(id):
	variables[variables[id]] = v;
      default:
	throw 'Dereferenced assignment of complex expressions is not implemented.';
      }
      return v;
    default:
      return super.assign(e1, e2);
    }
  }
}

/**
 Interface between a Hank story, and its embedded hscript interpreter
**/
@:allow(tests.HInterfaceTest)
class HInterface {
    var BOOLEAN_OPS = ['&&', '||', '!'];

  var parser: Parser;
  var interp: HankInterp;
    var viewCounts: Map<StoryNode, Int>;

  public function setStory(story: Story) {
    interp.setStory(story);
  }
  public function new(storyTree: StoryNode, viewCounts: Map<StoryNode, Int>) {

	this.parser = new Parser();
	parser.unops["*"] = false;
	parser.unops["&"] = false;
	parser.unops["->"] = false;
	this.interp  = new HankInterp(this);

        this.interp.variables['_isTruthy'] = isTruthy.bind(viewCounts);
        this.interp.variables['_valueOf'] = valueOf.bind(viewCounts);
        this.interp.variables['_resolve'] = resolveInScope.bind(this.interp.variables);
        this.interp.variables['_resolveField'] = resolveField.bind(this.interp.variables);
        this.viewCounts = viewCounts;

    }

    static function resolveInScope(variables: Map<String, Dynamic>, name: String): Dynamic {
        var scope: Array<Dynamic> = cast(variables['scope'], Array<Dynamic>);
        for (container in scope) {
            switch (resolve(variables, container, name)) {
                case Some(v):
                    return v;
                case None:
            }
        }

        throw 'Could not resolve $name in scope $scope.';
    }

    static function resolveField(variables: Map<String, Dynamic>, container: Dynamic, name: String): Dynamic {
        return resolve(variables, container, name).unwrap();
    }

    static function resolve(variables: Map<String, Dynamic>, container: Dynamic, name: String): Option<Dynamic> {
        if (variables.exists(name)) {
            return Some(variables[name]);
        } else if (Std.is(container, StoryNode)) {
            var node: StoryNode = cast(container, StoryNode);
            return node.resolve(name);
        }
        else {
            var val:Dynamic = container.field(name);
            if (val != null) {
                return Some(val);
            } else {
                return None;
            }
        }
    }

    static function isTruthy(viewCounts: Map<StoryNode, Int>, v: Dynamic) {
        if (Std.is(v, StoryNode)) {
            var node: StoryNode = cast(v, StoryNode);
            return viewCounts[node] > 0;
        }
        switch (Type.typeof(v)) {
            case TBool:
                return v;
            case TInt | TFloat:
                return v > 0;
            // TODO I would love to do away with this hack, but C++ type coercion turns random things into strings. This workaround fixes a specific bug
            default:
                if (Std.is(v, String)) {
                    var val = cast(v, String);
                    switch (val) {
                        case "true":
                            return true;
                        case "false":
                            return false;
                        default:
                            throw '$v: ${Type.typeof(v)} cannot be coerced to a boolean';
                    }
                }
                else throw '$v: ${Type.typeof(v)} cannot be coerced to a boolean';

        }
    }

    public function addVariable(identifier: String, value: Dynamic) {
        this.interp.variables[identifier] = value;
    }

  public function getVariable(identifier: String) {
    return this.interp.variables[identifier];
  }

    /**
     Run a pre-processed block of Haxe embedded in a Hank story.
    **/
    public function runEmbeddedHaxe(h: String, scope: Array<Dynamic>) {
        interp.variables['scope'] = scope;

        // trace(h);
        var expr = parser.parseString(h);
        expr = transmute(expr);
        interp.execute(expr);
    }

    public function expr(h: String, scope: Array<Dynamic>):Dynamic {
        interp.variables['scope'] = scope;

        var expr = parser.parseString(h);
        expr = transmute(expr);
        var val: Dynamic = interp.expr(expr);

        if (val == null) {
            throw 'Expression ${h} evaluated to null';
        }
        
        var val2 = valueOf(viewCounts, val);
        //var type1 = Std.string(Type.typeof(val));
        //var type2 = Std.string(Type.typeof(val2));
        //if (type1 != type2)
            //trace('$val: $type1 became $val2: $type2');
        return val2;
    }

    public function cond(h: String, scope: Array<Dynamic>): Bool {
        var val: Dynamic = expr(h, scope);
        return isTruthy(viewCounts, val);
    }

    public function evaluateExpr(h: String, scope: Array<Dynamic>): String {
        return Std.string(expr(h, scope));
    }

    static function valueOf(viewCounts: Map<StoryNode, Int>, val: Dynamic): Dynamic {
        return if (Std.is(val, StoryNode)) {
            var node: StoryNode = cast(val, StoryNode);
            viewCounts[node];
        } else {
            val;
        };
    }

    static function viewCountOf(viewCounts: Map<StoryNode, Int>, val: Dynamic): Option<Int> {
        return if (Std.is(val, StoryNode)) {
            var node: StoryNode = cast(val, StoryNode);
            Some(viewCounts[node]);
        } else {
            None;
        };
    }

    /**
     Convert numerical value expressions to booleans for binary operations
    **/
    function boolify(expr: Expr): Expr {
        var newExpr = transmute(expr);
        //trace(newExpr);
        return ECall(EIdent('_isTruthy'), [newExpr]);
    }

    function valify(expr: Expr): Expr {
        return ECall(EIdent('_valueOf'), [transmute(expr)]);
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
                } else if (op == '=') {
                    EBinop(op, e1, e2);
                }
                else {
                    EBinop(op, valify(e1), valify(e2));
                }
            case EUnop(op, prefix, e):
                if (BOOLEAN_OPS.indexOf(op) != -1) {
                    EUnop(op, prefix, boolify(e));
                } else {
                    expr;
                }
            case ECall(e, params):
                // Here we get funky to make sure method calls are preserved as such (bound to their object) by matching ECall(EField(e, f), [])
                switch (e) {
                    case EField(innerE, f):
                        var obj = interp.expr(innerE);
                        if (obj != null) {
                            return expr;
                        }
                    default:
                }
                //trace(ECall(transmute(e), [for (ex in params) transmute(ex)]));
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