package tests;
import utest.Test;
import hank.StoryTestCase;

class TestMain extends Test {
    public static function main() {
        utest.UTest.run([new HInterfaceTest(), new HankBufferTest(), new ParserTest(), new StoryTestCase("examples"), new StoryTreeTest()]);
    }
}