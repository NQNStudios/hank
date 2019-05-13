package tests;
import utest.Test;
import hank.StoryTestCase;

class InternalsTestMain extends Test {
    public static function main() {
        utest.UTest.run([new HInterfaceTest(), new HankBufferTest(), new ParserTest(),  new StoryTreeTest(), new FileLoadingMacroTest()]);
    }
}