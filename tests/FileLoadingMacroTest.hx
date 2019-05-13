package tests;

import utest.Test;
import utest.Assert;
using hank.Extensions;
import hank.HankAssert;

@:build(hank.FileLoadingMacro.build(["README.md", "LICENSE", "examples/"]))
class FileLoadingMacroTest extends utest.Test {
    function testLoadIndividualFiles() {
        var buffer = fileBuffer("README.md");
        Assert.equals("# hank", buffer.takeLine().unwrap());

        buffer = fileBuffer("LICENSE");
        Assert.equals("MIT License", buffer.takeLine().unwrap());
    }

    function testLoadDirectoryRecursive() {
        var buffer = fileBuffer("examples/main/main.hank");
        Assert.equals("INCLUDE extra.hank", buffer.takeLine().unwrap());

        buffer = fileBuffer("examples/hello/main.hank");
        var buffer2 = fileBuffer("examples/hello/test1.hlog");
        HankAssert.equals(buffer.takeLine(), buffer2.takeLine());
    }
}