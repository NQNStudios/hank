package tests;
import utest.Test;

class TestMain extends Test {
    public static function main() {
        utest.UTest.run([new HankLexerTest(), new HInterfaceTest()]);
    }
}