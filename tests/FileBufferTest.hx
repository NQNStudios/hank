package tests;

import haxe.ds.Option;
import hank.FileBuffer;
import hank.FileBuffer.Position;

class FileBufferTest extends utest.Test {
    var file: FileBuffer;
    var path: String;
    var expectedPosition: Position;

    function setup() {
        path = 'examples/parsing/file.txt';
        file = new FileBuffer(path);
        expectedPosition = {
            file: path,
            line: 1,
            column: 1
        };
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
}