package tests;

import hank.Parser;
import hank.Parser.HankAST;
import hank.Output;
import hank.Output.OutputType;

class ParserTest extends utest.Test {
    var ast: HankAST;

    function nextExpr() {
        var next = ast[0];
        ast.remove(next);
        return next.expr;
    }

    function assertNextExpr(expr: ExprType) {
        HankAssert.equals(expr, nextExpr());
    }

    function testParseOutput() {
        var parser = new Parser();
        ast = parser.parseFile('examples/parsing/output.hank');
    }


    function testParseMisc() {
        var parser = new Parser();
        ast = parser.parseFile('examples/parsing/misc.hank');
        assertNextExpr(EComment("comments in Hank start with a double-slash"));
        assertNextExpr(EComment("Or you can split comments\nacross more than one line"));
        assertNextExpr(EComment("Or you can use block comments inline"));
        assertNextExpr(EHaxeLine('var demo_var = "dynamic content";'));
        assertNextExpr(EComment("Hank scripts can embed Haxe logic by starting a line with '~'"));
        assertNextExpr(EKnot("knot_example"));
    }
}