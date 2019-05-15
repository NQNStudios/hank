package tests.main;
import utest.Test;
import hank.StoryTestCase;

@:build(hank.FileLoadingMacro.build(["examples/"]))
class Examples extends Test {
    public static function main() {
        utest.UTest.run([new StoryTestCase("examples"
#if !sys
            , files
#end
        )]);
    }
}