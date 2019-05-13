package hank;

using StringTools;
import hank.Story.StoryFrame;
import hank.LogUtil;

import haxe.CallStack;
import utest.Assert;

@:build(hank.FileLoadingMacro.build(["README.md"]))
class StoryTestCase extends utest.Test {

    var testsDirectory: String;

    public function new(testsDirectory: String) {
        super();
        this.testsDirectory = testsDirectory;
    }

    public function testAllExamples() {
        trace(_serializedFiles);//['README.md']);
        return;
        var exampleFolders = sys.FileSystem.readDirectory(testsDirectory);

        // Iterate through every example in the examples folder
        for (folder in exampleFolders) {
            trace('Running tests for example "${folder}"');
            var files = sys.FileSystem.readDirectory('${testsDirectory}/${folder}');

            for (file in files) {
                if (file.endsWith('.hlog')) {

                    var disabled = file.indexOf("disabled") != -1;
                    var debug = file.indexOf("debug") != -1;
                    var partial = file.indexOf("partial") != -1;
                    if (!disabled) {
                        trace('    Running ${file}');
                        try {
                            validateAgainstTranscript('${testsDirectory}/${folder}/main.hank', '${testsDirectory}/${folder}/${file}', !partial, debug);
                        } catch (e: Dynamic) {
                            trace('Error testing $folder/$file at transcript line $lastTranscriptLine: $e');
                            LogUtil.prettyPrintStack(CallStack.exceptionStack());
                            Assert.fail();
                        }
                    }
                }
            }
        }

    }

    var lastTranscriptLine = 0;

    private function validateAgainstTranscript(storyFile: String, transcriptFile: String, fullTranscript: Bool = true, debug: Bool = false) {

        var transcriptLines = sys.io.File.getContent(transcriptFile).split('\n');
        // If the transcript starts with a random seed, make sure the story uses that seed
        var randomSeed = null;
        if (transcriptLines[0].startsWith('@')) {
            randomSeed = Std.parseInt(transcriptLines[0].substr(1));
            transcriptLines.remove(transcriptLines[0]);
        }

        var story: Story = null;
        try {
            story = Story.FromFile(storyFile, randomSeed);
        } catch (e: Dynamic) {
            trace('Error parsing $storyFile: $e');
            LogUtil.prettyPrintStack(CallStack.exceptionStack());
            Assert.fail();
            return;
        }

        story.hInterface.addVariable("DEBUG", debug);

        var i = 0;
        while (i < transcriptLines.length) {
            var line = transcriptLines[i];
            lastTranscriptLine = i;

            // Allow white-box story testing through expression value checks prefixed with #
            if (line.startsWith("#")) {
                var parts = line.substr(1).trim().split(':');
                HankAssert.equals(parts[1].trim(), story.hInterface.evaluateExpr(parts[0], story.nodeScopes));
                i +=1;
                continue;
            }
            var frame = story.nextFrame();
            if (line.startsWith("*")) {
                // Collect the expected set of choices from the transcript.
                var choices = new Array<String>();
                do {
                    choices.push(line.substr(2));

                    line = transcriptLines[++i];
                } while (line != null && line.startsWith("*"));

                // Assert that the storyframe is a corresponding HasChoices enum
                HankAssert.equals(HasChoices(choices), frame);

                continue;
            } else if (line.startsWith(">")) {
                // Make the choice given, and check for expected output.
                line = line.substr(1).ltrim();
                var firstColonIdx = line.indexOf(':');
                var index = Std.parseInt(line.substr(0, firstColonIdx))-1;
                var expectedOutput = line.substr(firstColonIdx+1).trim();
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

            if (frame == Finished) {
                break;
            }

            i += 1;
        }

        if (fullTranscript) {
            // After all transcript lines are validated, there should be nothing left in the story flow!
            HankAssert.equals(StoryFrame.Finished, story.nextFrame());
        }
    }
}