package hank;

import hank.Story.StoryFrame;

class StoryTestCase extends utest.Test {
     private function validateAgainstTranscript(storyFile: String, transcriptFile: String, fullTranscript: Bool = true) {

        var transcriptLines = sys.io.File.getContent(transcriptFile).split('\n');
        // If the transcript starts with a random seed, make sure the story uses that seed
        var randomSeed = null;
        if (StringTools.startsWith(transcriptLines[0], '@')) {
            randomSeed = Std.parseInt(transcriptLines[0].substr(1));
            transcriptLines.remove(transcriptLines[0]);
        }

        var story: Story = new Story(storyFile, randomSeed);

        var i = 0;
        while (i < transcriptLines.length) {
            var line = transcriptLines[i];
            var frame = story.nextFrame();

            // Allow white-box story testing through variable checks prefixed with #
            if (StringTools.startsWith(line, "#")) {
                var parts = StringTools.trim(line.substr(1)).split(':');
                HankAssert.equals(StringTools.trim(parts[1]), Std.string(story.hInterface.getVariable(parts[0])));
            }
            if (StringTools.startsWith(line, "*")) {
                // Collect the expected set of choices from the transcript.
                var choices = new Array<String>();
                do {
                    choices.push(line.substr(2));

                    line = transcriptLines[++i];
                } while (line != null && StringTools.startsWith(line, "*"));

                // Assert that the storyframe is a corresponding HasChoices enum
                HankAssert.equals(HasChoices(choices), frame);

                continue;
            } else if (StringTools.startsWith(line, ">")) {
                // Make the choice given, and check for expected output.
                line = StringTools.ltrim(line.substr(1));
                var firstColonIdx = line.indexOf(':');
                var index = Std.parseInt(line.substr(0, firstColonIdx))-1;
                var expectedOutput = StringTools.trim(line.substr(firstColonIdx+1));
                // trace('expecting: ${expectedOutput}');
                var output = story.choose(index);
                // trace('got: ${output}');
                HankAssert.equals(expectedOutput, output);
            }
            else if (line.length > 0) {
                // Assert that the story's next frame is HasText(line)
                // trace('${line} from ${frame}');
                HankAssert.equals(HasText(line), frame);
            }

            i += 1;
        }

        if (fullTranscript) {
            // After all transcript lines are validated, there should be nothing left in the story flow!
            HankAssert.equals(StoryFrame.Finished, story.nextFrame());
        }
    }
}