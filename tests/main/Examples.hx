package tests.main;
import utest.Test;
import hank.StoryTestCase;
import hank.LogUtil;

@:build(hank.FileLoadingMacro.build(["examples/"]))
class Examples extends Test {
    public static function main() {
        trace('Testing examples for target ${LogUtil.currentTarget()}');
        utest.UTest.run([new StoryTestCase("examples"
#if !sys
            , files
#end
        )]);
    }
}