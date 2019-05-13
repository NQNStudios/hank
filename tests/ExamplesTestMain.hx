package tests;
import utest.Test;
import hank.StoryTestCase;

class ExamplesTestMain extends Test {
    public static function main() {
        utest.UTest.run([new StoryTestCase("examples")]);
    }
}