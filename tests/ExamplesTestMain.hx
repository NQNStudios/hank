package tests;
import utest.Test;
import hank.StoryTestCase;

@:build(hank.FileLoadingMacro.build(["examples/"]))
class ExamplesTestMain extends Test {
    public static function main() {
        utest.UTest.run([new StoryTestCase("examples"
#if !sys
            , files
#end
        )]);
    }
}