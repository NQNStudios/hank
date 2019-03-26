package hank;

import utest.Assert;
import haxe.ds.Option;

class HankAssert {
    /**
    Assert that two complex values (i.e. algebraic enums) are the same.
    **/
    public static function equals(expected: Dynamic, actual: Dynamic, ?pos: String) {
        var failureMessage = 'Assertion that ${actual} is ${expected} failed ${if (pos!= null) 'at ${pos}' else ''}';
        Assert.equals(Std.string(Type.typeof(expected)), Std.string(Type.typeof(actual)), failureMessage);
        Assert.equals(Std.string(expected), Std.string(actual), failureMessage);
    }

    /** Assert that a string contains an expected substring. **/
    public static function contains(expected: String, actual: String) {
        Assert.notEquals(-1, actual.indexOf(expected));
    }

    /**
    Assert that a string does not contain an unexpected substring.
    **/
    public static function notContains(unexpected: String, actual: String) {
        Assert.equals(-1, actual.indexOf(unexpected));
    }

    public static function isSome<T>(option: Option<T>) {
        switch (option) {
            case Some(_):
            case None:
                Assert.fail();
        }
    }

    public static function isNone<T>(option: Option<T>) {
        switch (option) {
            case Some(_):
                Assert.fail();
            case None:
        }
    }


}