package hank;

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


    public function new(script: String, ?randomSeed: Int) {
        random = new Random(randomSeed);

        parser = new Parser();
        ast = parser.parseFile(script);

        storyTree = StoryNode.FromAST(ast);
        nodeScopes = [storyTree];
        viewCounts = storyTree.createViewCounts();

        hInterface = new HInterface(storyTree, viewCounts);
        hInterface.addVariable('story', this);

        exprIndex = ast.findFile(script);
    }

    public function nextFrame(): StoryFrame {
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
                    trace('found outer part ${targetParts[0]}');
                    newScopes = whichScope.slice(i);
                    newScopes.insert(0, node);
                    trace(newScopes);
                    // Then resolve the rest of the parts inward from there
                    for (part in targetParts.slice(1)) {
                        trace('trying to find $part');
                        var scope = newScopes[0];
                        switch (scope.resolve(part)) {
                            case Some(innerNode):
                                trace('found $part');
                                newScopes.insert(0, innerNode);
                            case None:
                                break;
                        }
                    }
                    break;

                case None:
            }
        }
        trace('done seraching');
        return newScopes;
    }

    public function divertTo(target: String) {
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
                viewCounts[target] + 1;

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
        // TODO if the choice has a label, increment its view count
        return '';
    }

    /** Parse and run embedded Hank script on the fly. **/
    public function runEmbeddedHank(hank: String) {
        // TODO       
    }
}