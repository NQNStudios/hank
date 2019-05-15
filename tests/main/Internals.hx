package tests.main;
import utest.Test;
import hank.StoryTestCase;
import hank.LogUtil;

class Internals extends Test {
    public static function main() {
        trace('Testing internals for target ${LogUtil.currentTarget()}');
        utest.UTest.run([new HInterfaceTest(), new HankBufferTest(), new ParserTest(),  new StoryTreeTest(), new FileLoadingMacroTest()]);
    }
}