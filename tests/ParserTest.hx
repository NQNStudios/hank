package tests;

import hank.Parser;

class ParserTest extends utest.Test {
    function testParseMain() {
        var parser = new Parser();
        var ast = parser.parseFile('examples/main/main.hank');
        trace (ast);
    }
}