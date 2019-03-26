package tests;

import utest.Test;
import utest.Assert;

import hank.HankAssert;
using hank.Extensions;
import hank.HInterface;
import hank.StoryTree;
import hank.Parser;

class HInterfaceTest extends utest.Test {

    var hInterface: HInterface;

    public function setup() {
        var storyTree = StoryNode.FromAST(new Parser().parseFile("examples/subsections/main.hank"));
        hInterface = new HInterface(storyTree, [
            storyTree.resolve("start").unwrap() => 5,

        ]);
    }

    function assertExpr(name: String, value: Dynamic) {
        Assert.equals(Std.string(value), hInterface.evaluateExpr(name));
    }

    function testViewCount() {
        assertExpr('start', 5);
    }

    public function testVarDeclaration() {
        hInterface.runEmbeddedHaxe('var test = "str"');
        assertExpr('test', 'str');
        hInterface.runEmbeddedHaxe('var test2 = 2');
        assertExpr('test2', 2);
    }

    public function testBoolification() {
        hInterface.runEmbeddedHaxe('var test = 7; var test2 = if(test) true else false;');
        assertExpr('test2', true);
    }

    public function testNullErrors() {
       HankAssert.throws(function() {
           hInterface.evaluateExpr('undeclared_variable');
       });
    }

    public function testIfIdiom() {
       HankAssert.equals("", hInterface.evaluateExpr('if (false) "something"'));
    }

}
