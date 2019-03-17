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
        assertNextExpr(EOutput(new Output([Text("This file contains test cases for output expression parsing.")])));
        assertNextExpr(EOutput(new Output([Text("A line won't be interrupted  or anything.")])));
    }


    function testParseMisc() {
        var parser = new Parser();
        ast = parser.parseFile('examples/parsing/misc.hank');
        assertNextExpr(EHaxeLine('var demo_var = "dynamic content";'));
        assertNextExpr(EKnot("knot_example"));
    }
}