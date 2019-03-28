package hank;

import haxe.ds.Option;

using hank.Extensions;
using HankAST.ASTExtension;
import hank.HankAST.ExprType;
import hank.StoryTree;

/**
 Possible states of the story being executed.
**/
enum StoryFrame {
    HasText(text: String);
    HasChoices(choices: Array<String>);
    Finished;
}

/**
 Runtime interpreter for Hank stories.
**/
@:allow(hank.StoryTestCase)
class Story {
    var hInterface: HInterface;
    var random: Random;

    var ast: HankAST;
    var exprIndex: Int;

    var storyTree: StoryNode;
    var viewCounts: Map<StoryNode, Int>;
    var nodeScopes: Array<StoryNode>;

    var parser: Parser;

    var embeddedBlocks: Array<Story> = [];
    var parent: Option<Story> = None;

    function new(r: Random, p: Parser, ast: HankAST, st: StoryNode, sc: Array<StoryNode>, vc: Map<StoryNode, Int>, hi: HInterface) {
        this.random = r;
        this.parser = p;
        this.ast = ast;
        this.storyTree = st;
        this.nodeScopes = sc;
        this.viewCounts = vc;
        this.hInterface = hi;
    }

    function embeddedStory(h: String): Story {
        var ast = parser.parseString(h);

        var story = new Story(random, parser, ast, storyTree, nodeScopes, viewCounts, hInterface);
        story.exprIndex = 0;
        story.parent = Some(this);
        return story;
    }

    public static function FromFile(script: String, ?randomSeed: Int): Story {
        var random = new Random(randomSeed);

        var parser = new Parser();
        var ast = parser.parseFile(script);

        var storyTree = StoryNode.FromAST(ast);
        var nodeScopes = [storyTree];
        var viewCounts = storyTree.createViewCounts();

        var hInterface = new HInterface(storyTree, viewCounts);

        var story = new Story(random, parser, ast, storyTree, nodeScopes, viewCounts, hInterface);
        hInterface.addVariable('story', story);

        story.exprIndex = ast.findFile(script);
        return story;
    }

    public function nextFrame(): StoryFrame {
        while (embeddedBlocks.length > 0) {
            var nf = embeddedBlocks[0].nextFrame();
            if(nf == Finished) {
                embeddedBlocks.remove(embeddedBlocks[0]);
            } else {
                return nf;
            }
        }
        if (exprIndex >= ast.length) {
            return Finished;
        }
        return processExpr(ast[exprIndex].expr);
    }

    private function processExpr(expr: ExprType) {
        switch (expr) {
            case EOutput(output):
                exprIndex += 1;
                return HasText(output.format(hInterface, nodeScopes, false));
            case EHaxeLine(h):
                exprIndex += 1;

                hInterface.runEmbeddedHaxe(h, nodeScopes);
                return nextFrame();
            case EHaxeBlock(h):
                exprIndex += 1;
                hInterface.runEmbeddedHaxe(h, nodeScopes);
                return nextFrame();
            case EDivert(target):
                return divertTo(target);

            case EGather(label, depth, nextExpr):
                // gathers need to update their view counts
                switch (label) {
                    case Some(l):
                        var node = resolveNodeInScope(l)[0];
                        viewCounts[node] += 1;
                    case None:
                }
                // TODO update current weave depth
                return processExpr(nextExpr);
                
            default:
                trace('$expr is not implemented');
                return Finished;
        }
        return Finished;
    }

    private function resolveNodeInScope(label: String, ?whichScope: Array<StoryNode>): Array<StoryNode> {
        if (whichScope == null) whichScope = nodeScopes;

        // Resolve the target's first part from the deepest current scope outwards
        var targetParts = label.split('.');

        var newScopes = [];
        for (i in 0...whichScope.length) {
            var scope = whichScope[i];
            switch (scope.resolve(targetParts[0])) {
                case Some(node):
                    newScopes = whichScope.slice(i);
                    newScopes.insert(0, node);
                    // Then resolve the rest of the parts inward from there
                    for (part in targetParts.slice(1)) {
                        var scope = newScopes[0];
                        switch (scope.resolve(part)) {
                            case Some(innerNode):
                                newScopes.insert(0, innerNode);
                            case None:
                                break;
                        }
                    }
                    break;

                case None:
            }
        }
        return newScopes;
    }

    public function divertTo(target: String) {
        switch (parent) {
            case Some(p):
                p.embeddedBlocks = []; // 
                return p.divertTo(target); // A divert from inside embedded hank, ends the embedding
            default:
        }
        trace('diverting to $target');
        var newScopes = resolveNodeInScope(target);
        var targetIdx = newScopes[0].astIndex;

        if (targetIdx == -1) {
            throw 'Divert target not found: $target';
        }
        // update the expression index
        exprIndex = targetIdx; 
        var target = newScopes[0];

        // Update the view count
        switch (ast[exprIndex].expr) {
            case EKnot(_):
                // if it's a knot, increase its view count and increase index by one more 
                viewCounts[target] += 1;

                exprIndex += 1;
                // If a knot directly starts with a stitch, run it
                switch (ast[exprIndex].expr) {
                    case EStitch(label):
                        var firstStitch = resolveNodeInScope(label, newScopes)[0];
                        viewCounts[firstStitch] += 1;
                        exprIndex += 1;
                    default:
                }

            case EStitch(_):
                // if it's a stitch, increase its view count
                viewCounts[target] += 1;

                var enclosingKnot = newScopes[1];
                // If we weren't in the stitch's containing section before, increase its viewcount
                if (nodeScopes.indexOf(enclosingKnot) == -1) {
                    viewCounts[enclosingKnot] += 1;
                }
                exprIndex += 1;

            // TODO if it's a choice, choose it, and return HasText(output).
            case EChoice(_):
                return Finished;

            // Choices and gathers update their own view counts
            default:
        }
        // Update nodeScopes to point to the new scope
        nodeScopes = newScopes;

        return nextFrame();
    }

    public function choose(choiceIndex: Int): String {
        if (embeddedBlocks.length > 0) {
            return embeddedBlocks[0].choose(choiceIndex);
        } else {
            // if not embedded, actually make the choice
            // TODO if the choice has a label, increment its view count
            // TODO update the weave depth
            return '';
        }
    }

    /** Parse and run embedded Hank script on the fly. **/
    public function runEmbeddedHank(h: String) {
        embeddedBlocks.push(embeddedStory(h));
    }
}