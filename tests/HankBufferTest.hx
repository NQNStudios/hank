package tests;

using hank.Extensions.Extensions;

import haxe.ds.Option;
import hank.HankBuffer;
import hank.HankBuffer.Position;
import hank.HankAssert;

@:build(hank.FileLoadingMacro.build(["examples/parsing/"]))
class HankBufferTest extends utest.Test {
    var file: HankBuffer;
    var path: String;
    var expectedPosition: Position;

    function setup() {
        path = 'examples/parsing/file.txt';
        file = HankBuffer.FromFile(path, files);
        expectedPosition = new Position(path, 1, 1);
    }

    function assertPosition() {
        HankAssert.equals(expectedPosition, file.position());
    }

    function testPeek() {
        assertPosition();
        HankAssert.equals(Some({ output: 'Line', terminator: " "}), file.peekUntil(" ".split("")));
        // Repeated calls should return the same result
        HankAssert.equals(Some({ output: 'Line', terminator: " "}), file.peekUntil(" ".split("")));
        // And leave position unmodified
        assertPosition();

        // Once more for good measure
        HankAssert.equals(Some({ output: 'Line', terminator: " "}), file.peekUntil(" ".split("")));
        assertPosition();
    }

    function testTake() {
        var twoLines = file.take(27+20);
        HankAssert.equals("Line of text.\nLine of text  without a comment.\n", twoLines);
        expectedPosition.line = 3;
        expectedPosition.column = 1;
        assertPosition();
    }

    function testTakeUntil() {
        assertPosition();

        HankAssert.equals(Some({ output: 'Line', terminator: " "}), file.takeUntil(" ".split("")));
        expectedPosition.column += 5; // The terminator is dropped by default
        assertPosition();

        HankAssert.equals(Some({ output: 'of text.', terminator: "\n"}), file.takeUntil("\n".split("")));
        expectedPosition.line = 2; 
        expectedPosition.column = 1;
        assertPosition();

        HankAssert.equals(Some({ output: 'Line', terminator: " "}), file.takeUntil(" ".split(""), false, false));
        expectedPosition.column += 4; // The terminator doesn't have to be dropped
        assertPosition();

        HankAssert.equals(Some({ output: ' of text  without a comment.', terminator: '\n'}), file.takeUntil('\n'.split("")));
        expectedPosition.line = 3;
        expectedPosition.column = 1;
        assertPosition();
    }

    function testPeekLine() {
        assertPosition();
        HankAssert.equals(Some('Line of text.'), file.peekLine());
        assertPosition();
        HankAssert.equals(Some('Line of text.'), file.peekLine());
        assertPosition();
        file.takeLine();
        HankAssert.equals(Some('Line of text  without a comment.'), file.peekLine());
    }

    function testTakeLine() {
        assertPosition();

        HankAssert.equals(Some('Line of text.'), file.takeLine());
        expectedPosition.line += 1;
        assertPosition();

        HankAssert.equals(Some('Line of text  without a comment.'), file.takeLine());
        expectedPosition.line += 1;
        assertPosition();

        HankAssert.equals(Some('Two lines of text  that will be returned at the same time.'), file.takeLine());
        expectedPosition.line += 2;
        assertPosition();

        HankAssert.equals(Some('The fifth line of text. '), file.takeLine());
        expectedPosition.line += 1;
        assertPosition();

        HankAssert.equals(Some('Number six.'), file.takeLine());
        expectedPosition.column += 11;
        assertPosition();

        // EOF
        HankAssert.equals(None, file.takeLine());
    }

    function testGetLineTrimming() {
        file = HankBuffer.FromFile('examples/parsing/whitespace.txt', files);

        HankAssert.equals(Some("Just give me this output."), file.peekLine("lr"));
        HankAssert.equals(Some("        Just give me this output."), file.peekLine("r"));
        HankAssert.equals(Some("        Just give me this output.     "), file.peekLine(""));
        HankAssert.equals(Some("Just give me this output.     "), file.takeLine("l"));

        HankAssert.equals(Some("and on the next line, this output."), file.takeLine("lr"));
        HankAssert.equals(Some("Here, just this"), file.takeLine("lr"));
        HankAssert.equals(Some("I only want this stuff"), file.takeLine("lr"));
    }

    function testSkipWhitespace() {
        file = HankBuffer.FromFile('examples/parsing/whitespace.txt', files);

        file.skipWhitespace();
        HankAssert.equals("Just", file.take(4));
    }

    function testFindNestedExpression() {
        file = HankBuffer.FromFile('examples/parsing/nesting.txt', files);
        var slice1 = file.findNestedExpression('{', '}', 0);
        HankAssert.contains("doesn't contain what comes first", slice1.unwrap().checkValue());
        HankAssert.contains("Ends before here", slice1.unwrap().checkValue());
        var slice2 = file.findNestedExpression('{', '}', 1);
        HankAssert.notContains("doesn't contain what comes first", slice2.unwrap().checkValue());
        HankAssert.notContains("Ends before here", slice2.unwrap().checkValue());
        var slice3 = file.findNestedExpression('{{', '}}', 0);
        HankAssert.equals(52, slice3.unwrap().start);
        HankAssert.equals(6, slice3.unwrap().length);
    }
}