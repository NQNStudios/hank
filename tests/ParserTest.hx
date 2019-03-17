package tests;

import hank.Parser;
import hank.Parser.HankAST;
import hank.Output;
import hank.Alt;

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
        assertNextExpr(EOutput(new Output([Text("Multiline comments  an output expression. This should parse as one line of output.")])));
        assertNextExpr(EOutput(new Output([Text("Comments at the end of lines won't parse as part of the Output.")])));
        assertNextExpr(EOutput(new Output([Text("You can "), HExpression("insert"), Text(" the values of expressions.")])));
        assertNextExpr(EOutput(new Output([HExpression("you"), Text(" can start an output line with an insert expression. "), HExpression("and_end_one")])));
        
        assertNextExpr(
            EOutput(new Output([
                AltExpression(
                    new Alt(
                        Shuffle, 
                        [
                            new Output([Text("Things get weird")]), 
                            new Output([Text("when you start to use sequence expressions.")])
                        ]
                    )
                )
            ]))
        );
        assertNextExpr(
            EOutput(new Output([
                AltExpression(
                    new Alt(
                        OnceOnly, 
                        [
                            new Output([Text("And they don't get any "), HExpression("easier")]), 
                            new Output([AltExpression(
                                new Alt(
                                    Sequence,
                                    [
                                        new Output([Text("when you nest them")]),
                                        new Output([HExpression("insert")])
                                    ]
                                )
                            )]
                        )]
                    )
                ), Text("!")
            ]))
        );

        assertNextExpr(EOutput(new Output([Text("You can "), HExpression('\n    if (flag) "insert" else "interpolate"\n'), Text(" the value of multiline expressions without splitting a line of output.")])));
        assertNextExpr(EOutput(new Output([Text("You can have diverts inline. "), InlineDivert("somewhere_else")])));
        assertNextExpr(EOutput(new Output([Text("You can have diverts as branches of a sequence "), AltExpression(
            new Alt(Sequence, [
                new Output([
                    InlineDivert("first_time")
                ]),
                new Output([
                    InlineDivert("second_time")
                ])
            ]))
        ])));
        assertNextExpr(EOutput(new Output([
            Text("You can have partial output"),
            ToggleOutput(new Output([Text(".")]), false),
            ToggleOutput(new Output([Text(" that changes after a choice is made!")]), true)
        ])));
        trace(nextExpr());
    }


    function testParseMisc() {
        var parser = new Parser();
        ast = parser.parseFile('examples/parsing/misc.hank');
        assertNextExpr(EHaxeLine('var demo_var = "dynamic content";'));
        assertNextExpr(EKnot("knot_example"));
        assertNextExpr(EStitch("stitch_example"));
        assertNextExpr(EDivert("divert_example"));
        assertNextExpr(EDivert("divert_example"));
        assertNextExpr(EDivert("divert_example"));

        assertNextExpr(EHaxeBlock("var haxeVar = 'test';var test2 = 5;"));
        assertNextExpr(EHaxeBlock('story.runEmbeddedHank("Output this");'));
        assertNextExpr(EHaxeBlock('story.runEmbeddedHank("Output \\"this\\"");'));
    }
}