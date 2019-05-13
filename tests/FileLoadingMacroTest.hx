package tests;

import utest.Test;
import utest.Assert;
using hank.Extensions;

@:build(hank.FileLoadingMacro.build(["README.md", "LICENSE"]))
class FileLoadingMacroTest extends utest.Test {
    function testLoadFiles() {
        var buffer = fileBuffer("README.md");
        Assert.equals("# hank", buffer.takeLine().unwrap());
    }
}