package tests;

import utest.Assert;

class HankAssert {
    /**
    Assert that two complex values (i.e. algebraic enums) are the same.
    **/
    public static function equals(expected: Dynamic, actual: Dynamic, ?pos: String) {
        var failureMessage = 'Assertion that ${actual} is ${expected} failed ${if (pos!= null) 'at ${pos}' else ''}';
        Assert.equals(Std.string(Type.typeof(expected)), Std.string(Type.typeof(actual)), failureMessage);
        Assert.equals(Std.string(expected), Std.string(actual), failureMessage);
    }
}