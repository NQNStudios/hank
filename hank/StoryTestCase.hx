package hank;

import utest.Assert;
import hank.HankLines;
import hank.StoryFrame;

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

        var transcriptLines = sys.io.File.getContent(transcriptFile).split('\n');
        // If the transcript starts with a random seed, make sure the story uses that seed
        var randomSeed = null;
        if (StringTools.startsWith(transcriptLines[0], '@')) {
            randomSeed = Std.parseInt(transcriptLines[0].substr(1));
            transcriptLines.remove(transcriptLines[0]);
        }

        var story: Story = new Story(randomSeed, debug,'validating.hlog', debugPrints);
        story.loadScript(storyFile);

        var i = 0;
        while (i < transcriptLines.length) {
            var line = transcriptLines[i];
            var frame = null;
            try {
                frame = story.nextFrame();
            } catch (e: Dynamic) {
                trace('Error at ${story.lastLineID} while validating ${transcriptFile}');

                throw e;
            }

            if (debugPrints) {
                trace('Frame ${i}: ${Std.string(frame)}');
            }

            // Allow white-box story testing through variable checks prefixed with #
            if (StringTools.startsWith(line, "#")) {
                var parts = StringTools.trim(line.substr(1)).split(':');
                Assert.equals(StringTools.trim(parts[1]), Std.string(story.interp.variables[parts[0]]) );
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
            } else if (StringTools.startsWith(line, ">")) {
                // Make the choice given, and check for expected output.
                line = StringTools.ltrim(line.substr(1));
                var firstColonIdx = line.indexOf(':');
                var index = Std.parseInt(line.substr(0, firstColonIdx))-1;
                var expectedOutput = StringTools.trim(line.substr(firstColonIdx+1));
                trace('expecting: ${expectedOutput}');
                try {
                    var output = story.choose(index);
                    trace('got: ${output}');
                    Assert.equals(expectedOutput, output);
                } catch (e: Dynamic) {
                    trace('Error at ${story.lastLineID} while validating ${transcriptFile}');

                    throw e;
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