package src;

import utest.Assert;
import src.StoryFrame;
import src.HankLines.LineID;

class StoryTestCase extends utest.Test {
    /**
    Assert that two complex values (i.e. algebraic enums) are the same.
    **/
    private function assertComplexEquals(expected: Dynamic, actual: Dynamic, pos: LineID=null) {
        if (pos == null) pos = new LineID('', 0);
        var failureMessage = 'Assertion that ${actual} is ${expected} failed at ${pos}';
        Assert.equals(Std.string(Type.typeof(expected)), Std.string(Type.typeof(actual)), failureMessage);
        Assert.equals(Std.string(expected), Std.string(actual), failureMessage);
    }

    private function validateAgainstTranscript(storyFile: String, transcriptFile: String, fullTranscript: Bool = true, debug: Bool = false, debugPrints: Bool = false) {

        if (debugPrints) trace('validating ${storyFile}');

        var story: Story = new Story(debug,'validating.hlog', debugPrints);
        story.loadScript(storyFile);
        var transcriptLines = sys.io.File.getContent(transcriptFile).split('\n');

        var i = 0;
        while (i < transcriptLines.length) {
            var line = transcriptLines[i];
            var frame = story.nextFrame();

            if (debugPrints) {
                trace('Frame ${i}: ${Std.string(frame)}');
            }

            if (StringTools.startsWith(line, "*")) {
                // Collect the expected set of choices from the transcript.
                var choices = new Array<String>();
                do {
                    choices.push(line.substr(2));

                    line = transcriptLines[++i];
                } while (line != null && StringTools.startsWith(line, "*"));
                if (debugPrints) { 
                    trace(choices);
                }

                // Assert that the storyframe is a corresponding HasChoices enum
                assertComplexEquals(HasChoices(choices), frame, story.lastLineID);

                continue;
            } else if (StringTools.startsWith(line, ">>>")) {
                // Make the choice given.
                var output = story.choose(Std.parseInt(StringTools.trim(line.substr(3))));
                if (debugPrints) {
                    trace(output);
                }
                if (fullTranscript || transcriptLines.length > i+1) {
                    // Assert that its output equals the transcript's expected choice output.
                    Assert.equals(transcriptLines[++i], output);
                }
            } else if (StringTools.startsWith(line, "#")) {
                // Allow comments in a transcript that need not be validated in any way
                if (debugPrints) {
                    trace(line);
                }
            }
            else if (line.length > 0) {
                // Assert that the story's next frame is HasText(line)
                // trace('${line} from ${frame}');
                assertComplexEquals(HasText(line), frame, story.currentLineID());
            }

            i += 1;
        }

        if (fullTranscript) {
            // After all transcript lines are validated, there should be nothing left in the story flow!
            Assert.equals(StoryFrame.Finished, story.nextFrame());
        }
        if (debugPrints) trace('done with ${storyFile}');
    }
}