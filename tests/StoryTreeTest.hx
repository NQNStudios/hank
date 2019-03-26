package tests;

import utest.Assert;
import hank.HankAssert;
import hank.StoryTree;
import hank.Parser;
using hank.Extensions;

class StoryTreeTest extends utest.Test {
    var tree: StoryNode;

    function setupClass() {
        tree = new StoryNode(0);
        var section = new StoryNode(1);
        var subsection = new StoryNode(2);

        var globalVar = new StoryNode(3);
        var sectionVar = new StoryNode(4);
        var subsectionVar = new StoryNode(5);

        tree.addChild("section", section);
        tree.addChild("ambiguous", globalVar);

        section.addChild("ambiguous", sectionVar);
        section.addChild("subsection", subsection);
        subsection.addChild("ambiguous", subsectionVar);
    }

    function testTraverseAll() {
        var allNodes = tree.traverseAll();

        HankAssert.equals(6, allNodes.length);
    }

    function testResolve() {
        var global = tree.resolve("ambiguous");
        HankAssert.equals(3, global.unwrap().astIndex);
    }

    function testParse() {
        var tree = StoryNode.FromAST(new Parser().parseFile("examples/subsections/main.hank"));

        HankAssert.isSome(tree.resolve("start"));
        HankAssert.isSome(tree.resolve("three"));
        HankAssert.isSome(tree.resolve("other_section"));
        // Resolving a nonexistent name should throw
        HankAssert.isNone(tree.resolve("one"));
        HankAssert.isSome(tree.resolve("start").unwrap().resolve("end"));
        HankAssert.isNone(tree.resolve("start").unwrap().resolve("three"));
        HankAssert.isSome(tree.resolve("three").unwrap().resolve("three"));

        Assert.pass();
    }
}