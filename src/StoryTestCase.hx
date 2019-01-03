package src;

import utest.Assert;

class StoryTestCase extends utest.Test {
    /**
    Assert that two complex values (i.e. algebraic enums) are the same.
    **/
    private function assertComplexEquals(expected: Dynamic, actual: Dynamic) {
        Assert.equals(Std.string(Type.typeof(expected)), Std.string(Type.typeof(actual)));
        Assert.equals(Std.string(expected), Std.string(actual));
    }

    private function validateAgainstTranscript(storyFile: String, transcriptFile: String) {
        var story: Story = new Story();
        story.loadScript(storyFile);
        var transcriptLines = sys.io.File.getContent(transcriptFile).split('\n');

        var i = 0;
        while (i < transcriptLines.length) {
            var line = transcriptLines[i];

            if (StringTools.startsWith(line, "*")) {
                // Collect the expected set of choices from the transcript.
                var choices = new Array<String>();
                do {
                    choices.push(line.substr(2));

                    line = transcriptLines[++i];
                } while (StringTools.startsWith(line, "*"));

                // Assert that the storyframe is a corresponding HasChoices enum
                Assert.equals('HasChoices(${Std.string(choices)})', Std.string(story.nextFrame()));

                continue;
            } else if (StringTools.startsWith(line, ">>>")) {
                // Make the choice given.
                var output = story.choose(Std.parseInt(StringTools.trim(line.substr(3))));
                // Assert that its output equals the next line.
                Assert.equals(transcriptLines[++i], output);
            } else if (StringTools.startsWith(line, "#")) {
                // Allow comments in a transcript that need not be validated in any way
                trace(line);
            }
            else if (line.length > 0) {
                // Assert that the story's next frame is HasText(line)
                Assert.equals('HasText(${line})', Std.string(story.nextFrame()));
            }

            i += 1;
        }

        // After all transcript lines are validated, there should be nothing left in the story flow!
        Assert.equals(StoryFrame.Finished, story.nextFrame());
    }
}