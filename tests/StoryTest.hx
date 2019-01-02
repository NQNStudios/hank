package tests;

import src.Story;
import src.Story.HankLine;
import src.Story.LineType;
import src.StoryFrame;
import utest.Assert;

class StoryTest extends src.StoryTestCase {
    public static function main() {
        utest.UTest.run([new StoryTest()]);
    }

    public function testParseHelloWorld() {
        var story: Story = new Story();
        story.loadScript("examples/hello.hank");
        assertLineType('OutputText(Hello, world!)', story.scriptLines[0]);
    }

    public function testHelloWorld() {
        var story: Story = new Story();
        story.loadScript("examples/hello.hank");
        assertComplexEquals(HasText("Hello, world!"), story.nextFrame());
        Assert.equals(StoryFrame.Finished, story.nextFrame());
        Assert.equals(StoryFrame.Finished, story.nextFrame());
    }

    public function testRunFullSpec2() {
        validateAgainstTranscript("examples/main.hank", "examples/tests/main1.hanktest");
    }

    public function testRunFullSpec3() {
        validateAgainstTranscript("examples/main.hank", "examples/tests/main2.hanktest");
    }

    /**
    Keep this clunky thing around to sanity check validateAgainstTranscript()
    **/
    public function testRunFullSpec1() {
        var story: Story = new Story(true, "transcript.hanktest");
        story.loadScript("examples/main.hank");
        var frame1 = story.nextFrame();
        // This calls the INCLUDE statement. Ensure that all lines
        // were included
        Assert.equals(38+22, story.lineCount);

        assertComplexEquals(HasText("This is a section of a Hank story. It's pretty much like a Knot in Ink."), frame1);
        assertComplexEquals(HasText("Line breaks define the chunks of this section that will eventually get sent to your game to process!"), story.nextFrame());
        assertComplexEquals(HasText("Your Hank scripts will contain the static content of your game, but they can also insert dynamic content, even the result of complex haxe expressions!"), story.nextFrame());
        assertComplexEquals(HasText("You can include choices for the player."), story.nextFrame());

        assertComplexEquals(HasChoices(["Door A looks promising!", "Door B"]), story.nextFrame());

        Assert.equals("Door A opens and there's nothing behind it.", story.choose(0));

        assertComplexEquals(HasText("You can include choices for the player."), story.nextFrame());
        assertComplexEquals(HasChoices(["Door B,Choices can depend on logical conditions being truthy."]), story.nextFrame());

        // Picking the same + choice should loop
        Assert.equals("Door B opens but the room on the other side is identical!", story.choose(0)); 
        assertComplexEquals(HasText("You can include choices for the player."), story.nextFrame());
        assertComplexEquals(HasChoices(["Door B","Choices can depend on logical conditions being truthy."]), story.nextFrame());
        Assert.equals("Door B opens but the room on the other side is identical!", story.choose(0)); 
        assertComplexEquals(HasText("You can include choices for the player."), story.nextFrame());
        assertComplexEquals(HasChoices(["Door B","Choices can depend on logical conditions being truthy."]), story.nextFrame());
        Assert.equals("Door B opens but the room on the other side is identical!", story.choose(0)); 
        assertComplexEquals(HasText("You can include choices for the player."), story.nextFrame());
        assertComplexEquals(HasChoices(["Door B","Choices can depend on logical conditions being truthy."]), story.nextFrame());

        Assert.equals("Choices can depend on logical conditions being truthy.", story.choose(1));

        assertComplexEquals(HasChoices(["I don't think I'll use Hank for my games.","Hank sounds awesome, thanks!"]), story.nextFrame());
        Assert.equals("I don't think I'll use Hank for my games.", story.choose(0));
        assertComplexEquals(HasText("Are you sure?"), story.nextFrame());
        assertComplexEquals(HasChoices(["Yes I'm sure.","I've changed my mind."]), story.nextFrame());
        Assert.equals("Yes I'm sure.", story.choose(0));
        assertComplexEquals(HasText("That's perfectly valid!"), story.nextFrame());
        assertComplexEquals(HasText("That's the end of this example!"), story.nextFrame());
        assertComplexEquals(HasText("This should say 'mouse': mouse"), story.nextFrame());
        Assert.equals(StoryFrame.Finished, story.nextFrame());

        // Validate the transcript that was produced
        validateAgainstTranscript("examples/main.hank", "transcript.hanktest");
    }

    public function testViewCounts() {
        var story = new Story(true);
        story.loadScript("examples/main.hank");

        Assert.equals(0, story.interp.variables['start']);
        Assert.equals(0, story.interp.variables['choice_example']);
        story.nextFrame();
        Assert.equals(1, story.interp.variables['start']);
        Assert.equals(0, story.interp.variables['choice_example']);
    }

    public function testParseLine() {
        var story = new Story();
        assertComplexEquals(IncludeFile("examples/extra.hank"),story.parseLine("INCLUDE examples/extra.hank", []));

        // TODO test edge cases of all line types (maybe with more separate functions too)
    }

    private function assertLineType(type: String, line: HankLine) {
        var actual = Std.string(line.type);
        Assert.equals(type, actual);
    }

    public function testParseFullSpec() {
        // Parse the main.hank script and test that all lines are correctly parsed
        var story = new Story(true);
        story.loadScript("examples/main.hank");
        Assert.equals(38+22, story.lineCount);

        // TODO test a few line numbers from the script to make sure the parsed versions match. Especially block line numbers

        // TODO test the extra.hank lines


        var lineTypes = [
            // TODO the 22 lines of the extra.hank file
            'IncludeFile(examples/extra.hank)',
            'Empty',
            'Divert(start)',
            'Empty',
            'DeclareSection(start)',
            'OutputText(This is a section of a Hank story. It\'s pretty much like a Knot in Ink.)',
            'OutputText(Line breaks define the chunks of this section that will eventually get sent to your game to process!)',
            'OutputText(Your Hank scripts will contain the static content of your game, but they can also insert {demo_var}, even the result of complex {part1 + " " + part2}!)',
            'Empty',
            'HaxeLine(var multiline_logic = "Logic can happen on any line before a multiline comment.";)',
            'BlockComment(3)',
            'Empty',
            'Empty',
            'HaxeLine(multiline_logic_example = "Logic can happen on any line after a multiline comment.";)',
            'Empty',
            'Divert(choice_example)',
            'Empty',
            'DeclareSection(final_choice)',
            'Empty',
            'HaxeBlock(5,var unused_variable="";\n// This is a comment INSIDE a haxe block\n/*The whole block will be parsed and executed at the same time*/\n)',
            'Empty',
            'Empty',
            'Empty',
            'Empty',
            'DeclareChoice({text: I don\'t think I\'ll use Hank for my games., id: 3, depth: 1, expires: true})',
            'OutputText(Are you sure?)',
            'DeclareChoice({text: Yes I\'m sure., id: 4, depth: 2, expires: true})',
            'OutputText(That\'s perfectly valid!)',
            'Divert(the_end)',
            'DeclareChoice({text: I\'ve changed my mind., id: 5, depth: 2, expires: true})',
            'Divert(final_choice)',
            'DeclareChoice({text: Hank sounds awesome, thanks!, id: 6, depth: 1, expires: true})',
            'Divert(the_end)',
            'Empty',
            'DeclareSection(the_end)',
            'Empty',
            'OutputText(That\'s the end of this example!)',
            'OutputText(This should say \'mouse\': {what_happened})'
        ];

        var idx = 22;
        var i = 0;
        while (idx < story.scriptLines.length) {
            assertLineType(lineTypes[i++], story.scriptLines[idx++]);
        }
    }
}