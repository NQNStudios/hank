package hank;

import haxe.ds.Option;

using hank.Extensions;
using HankAST.ASTExtension;
using HankAST.Choice;
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

    var choicesTaken: Array<Int> = [];
    var weaveDepth = 0;

    var storedFrame: Option<StoryFrame> = None;

    function new(r: Random, p: Parser, ast: HankAST, st: StoryNode, sc: Array<StoryNode>, vc: Map<StoryNode, Int>, hi: HInterface) {
        this.random = r;
        this.parser = p;
        this.ast = ast;
        this.storyTree = st;
        this.nodeScopes = sc;
        this.viewCounts = vc;
        this.hInterface = hi;
    }

    function currentFile() {
        return ast[0].position.file;
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
        switch (storedFrame) {
            case Some(f):
                storedFrame = None;
                return f;
            default:
        }
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

    private function processExpr(expr: ExprType): StoryFrame {
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
                divertTo(target);
                return nextFrame();

            case EGather(label, depth, nextExpr):
                // gathers need to update their view counts
                switch (label) {
                    case Some(l):
                        var node = resolveNodeInScope(l)[0];
                        viewCounts[node] += 1;
                    case None:
                }
                weaveDepth = depth;
                return processExpr(nextExpr);

            case EChoice(choice):
                if (choice.depth > weaveDepth) {
                    weaveDepth = choice.depth;
                } else if (choice.depth < weaveDepth) {
                    gotoNextGather();
                    return nextFrame();
                }

                var optionsText = [for(c in availableChoices()) c.output.format(hInterface, nodeScopes, false)];
                if (optionsText.length > 0) {
                    return HasChoices(optionsText);
                } else {
                    var fallback = fallbackChoice();
                    return HasText(evaluateChoice(fallback));
                }
            default:
                trace('$expr is not implemented');
                return Finished;
        }
        return Finished;
    }

    private function availableChoices(): Array<Choice> {
        var choices = [];
        var allChoices = ast.collectChoices(exprIndex, weaveDepth);
        for (choice in allChoices) {
            if (choicesTaken.indexOf(choice.id) == -1 || !choice.onceOnly) {
                switch (choice.condition) {
                    case Some(expr):
                        if (hInterface.expr(expr, nodeScopes)) {
                            choices.push(choice);
                        }
                    case None:
                        choices.push(choice);
                }
            }
        }

        return choices;
    }

    private function fallbackChoice(): Choice {
        var choices = ast.collectChoices(exprIndex, weaveDepth);
        var lastChoice = choices[choices.length-1];
        if (lastChoice.output.isEmpty()) {
            return lastChoice;
        } else {
            throw 'there is no fallback choice!';
        }
    }

    private function gotoNextGather() {
        // TODO implement this to fix the stack overflow
        var gatherIndex = ast.findNextGather(currentFile(), exprIndex+1,weaveDepth);

        if (gatherIndex == -1) {
            throw 'Ran out of choice content, and there is no gather';
        }
        
        exprIndex = gatherIndex;
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
                // A divert from inside embedded hank, must leave the embedded context
                p.embeddedBlocks = [];
                p.divertTo(target);
                exprIndex = ast.length; // Must return finished
                return;
            default:
        }
        var newScopes = resolveNodeInScope(target);
        var targetIdx = newScopes[0].astIndex;

        trace('diverting to $target');

        if (targetIdx == -1) {
            throw 'Divert target not found: $target';
        }
        // update the expression index
        exprIndex = targetIdx; 
        var target = newScopes[0];
        weaveDepth = 0;

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

            case EChoice(c):
                storedFrame = Some(HasText(evaluateChoice(c)));
                return;

            // Choices and gathers update their own view counts
            default:
        }
        // Update nodeScopes to point to the new scope
        nodeScopes = newScopes;
    }

    public function choose(choiceIndex: Int): String {
        // If embedded, let the embedded section evaluate the choice
        if (embeddedBlocks.length > 0) {
            return embeddedBlocks[0].choose(choiceIndex);
        } else {
            // if not embedded, actually make the choice
            return evaluateChoice(availableChoices()[choiceIndex]);
        }
    }

    function evaluateChoice(choice: Choice): String {
        // if the choice has a label, increment its view count 
        switch (choice.label) {
            case Some(l):
                var node = resolveNodeInScope(l)[0];
                viewCounts[node] += 1;
            case None:
        }
        weaveDepth = choice.depth + 1;
        // if the choice is onceOnly, add its id to the shit list
        if (choice.onceOnly) {
            choicesTaken.push(choice.id);
        }

        switch (choice.divertTarget) {
            case Some(t):
                divertTo(t);
            case None:
                exprIndex = ast.indexOfChoice(choice.id)+1;
        }

        var output = choice.output.format(hInterface, nodeScopes, true);
        return output;
    }

    /** Parse and run embedded Hank script on the fly. **/
    public function runEmbeddedHank(h: String) {
        embeddedBlocks.push(embeddedStory(h));
    }
}