package tests;

import utest.Test;
import utest.Assert;

import hank.HInterface;
import hank.StoryTree;

class HInterfaceTest extends utest.Test {

    var hInterface: HInterface;

    public function setup() {
        hInterface = new HInterface(new StoryNode(0), new Map());
    }

    function assertVar(name: String, value: Dynamic) {
        Assert.equals(value, hInterface.interp.variables[name]);
    }

    public function testVarDeclaration() {
        hInterface.runEmbeddedHaxe('var test = "str"');
        assertVar('test', 'str');
        hInterface.runEmbeddedHaxe('var test2 = 2');
        assertVar('test2', 2);
    }

    public function testBoolification() {
        hInterface.runEmbeddedHaxe('var test = 7; var test2 = if(test) true else false;');
        assertVar('test2', true);
    }

}
