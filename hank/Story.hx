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

    var parser: Parser;


    public function new(script: String, ?randomSeed: Int) {
        random = new Random(randomSeed);

        parser = new Parser();
        ast = parser.parseFile(script);

        storyTree = StoryNode.FromAST(ast);
        viewCounts = storyTree.createViewCounts();

        hInterface = new HInterface(storyTree, viewCounts);
        hInterface.addVariable('story', this);

        exprIndex = ast.findFile(script);
    }

    public function nextFrame(): StoryFrame {
        if (exprIndex >= ast.length) {
            return Finished;
        }

        switch (ast[exprIndex].expr) {
            case EOutput(output):
                exprIndex += 1;
                return HasText(output.format(hInterface, false));
            case EHaxeLine(h):
                exprIndex += 1;

                hInterface.runEmbeddedHaxe(h);
                return nextFrame();
            default:
                return Finished;
        }
        return Finished;
    }

    public function choose(choiceIndex: Int): String {
        return '';
    }

    /** Parse and run embedded Hank script on the fly. **/
    public function runEmbeddedHank(hank: String) {
        // TODO       
    }
}