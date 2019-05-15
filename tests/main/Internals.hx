package tests.main;
import utest.Test;
import hank.StoryTestCase;

class Internals extends Test {
    public static function main() {
        utest.UTest.run([new HInterfaceTest(), new HankBufferTest(), new ParserTest(),  new StoryTreeTest(), new FileLoadingMacroTest()]);
    }
}