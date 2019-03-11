package tests;

import haxe.ds.Option;
import hank.FileBuffer;
import hank.FileBuffer.Position;

class FileBufferTest extends utest.Test {
    var file: FileBuffer;

    function setup() {
        file = new FileBuffer('examples/main/main.hank');
    }

    function testPeek() {
        var expectedPosition = {
            file: 'examples/main/main.hank',
            line: 1,
            column: 0
        };
        HankAssert.equals(expectedPosition, file.position());
        HankAssert.equals(Some('INCLUDE'), file.peekUntil(" ".split("")));
        // Repeated calls should return the same result
        HankAssert.equals(Some('INCLUDE'), file.peekUntil(" ".split("")));
        // And leave position unmodified
        HankAssert.equals(expectedPosition, file.position());

        // Once more for good measure
        HankAssert.equals(Some('INCLUDE'), file.peekUntil(" ".split("")));
        HankAssert.equals(expectedPosition, file.position());
    }

    function testTake() {
        var expectedPosition1 = {
            file: 'examples/main/main.hank',
            line: 1,
            column: 0
        };
        var expectedPosition2 = {
            file: 'examples/main/main.hank',
            line: 1,
            column: 8
        };
        var expectedPosition3 = {
            file: 'examples/main/main.hank',
            line: 2,
            column: 0
        };

        HankAssert.equals(expectedPosition1, file.position());
        HankAssert.equals(Some('INCLUDE'), file.takeUntil(" ".split("")));
        HankAssert.equals(expectedPosition2, file.position());
        HankAssert.equals(Some('extra.hank'), file.takeUntil("\n".split("")));
        HankAssert.equals(expectedPosition3, file.position());
    }
}