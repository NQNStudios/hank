package hank;

using HankAST.ASTExtension;
import hank.HankAST.ExprType;

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

    var parser: Parser;

    public function new(script: String, ?randomSeed: Int) {
        random = new Random(randomSeed);

        parser = new Parser();
        ast = parser.parseFile(script);
        // viewCounts = new ViewCounts(ast);

        var variables = [
            'story' => this/*,
            'viewCounts' => viewCounts
            */
        ];
        hInterface = new HInterface(variables);

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