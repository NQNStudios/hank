package tests;

import hank.Parser;
import hank.Parser.HankAST;

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


    function testParseMain() {
        var parser = new Parser();
        ast = parser.parseFile('examples/main/main.hank');
        assertNextExpr(EComment(" comments in Hank start with a double-slash"));
        assertNextExpr(EComment(" Or you can split comments\nacross more than one line "));
        assertNextExpr(EComment(" Or you can use block comments inline "));

    }
}