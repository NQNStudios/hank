package tests;

import hank.Story;
import utest.Test;
import utest.Assert;

import hank.HInterface;

class HInterfaceTest extends utest.Test {

    var hInterface: HInterface;

    public function setup() {
        hInterface = new HInterface(new Story());
    }

    function assertVar(name: String, value: Dynamic) {
        Assert.equals(value, hInterface.interp.variables[name]);
    }

    public function testVarDeclaration() {
        hInterface.runEmbeddedHaxe('var test = "str"');
        assertVar('test', 'str');
    }

    public function testBoolification() {
        hInterface.runEmbeddedHaxe('var test = 7; var test2 = if(test) true else false;');
        assertVar('test2', true);
    }

}
