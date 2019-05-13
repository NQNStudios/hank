package hank;

using StringTools;
import hank.Story.StoryFrame;
import hank.LogUtil;
import hank.HankBuffer;

import haxe.CallStack;
import utest.Assert;

class StoryTestCase extends utest.Test {

    var testsDirectory: String;
    var files: PreloadedFiles = new Map();

    public function new(testsDirectory: String, ?preloadedFiles: PreloadedFiles) {
        super();
        this.testsDirectory = testsDirectory;
        if (preloadedFiles != null)
            this.files = preloadedFiles;
    }

    public function testAllExamples() {
        var exampleTranscripts: Map<String, Array<String>> = new Map();
#if sys
        var exampleFolders = sys.FileSystem.readDirectory(testsDirectory);
        for (folder in exampleFolders) {
            var files = sys.FileSystem.readDirectory('${testsDirectory}/${folder}');
            exampleTranscripts.set(folder, [for(file in files) if (file.endsWith('.hlog')) file]);
        }
#else
        for (file in files.keys()) {
            var parts = file.split('/');

            if (parts[0] != testsDirectory) {
                continue;
            }

            var folder = parts[1];
            if (!exampleTranscripts.exists(folder)) {
                exampleTranscripts.set(folder, new Array());
            }
            
            if (parts[2].endsWith('.hlog')) {
                exampleTranscripts[folder].push(parts[2]);
            }
        }
#end

        for (folder in exampleTranscripts.keys()) {
            if (folder.startsWith('_')) {
                trace('Skipping tests for example "${folder}"');
                continue;
            }
            trace('Running tests for example "${folder}"');

            for (file in exampleTranscripts[folder]) {
                var disabled = file.indexOf("disabled") != -1;
                var debug = file.indexOf("debug") != -1;
                var partial = file.indexOf("partial") != -1;
                if (!disabled) {
                    trace('    Running ${file}');
#if !sys
                    validateAgainstTranscript('${testsDirectory}/${folder}/main.hank', '${testsDirectory}/${folder}/${file}', !partial, debug);
#else
                    try {
                        validateAgainstTranscript('${testsDirectory}/${folder}/main.hank', '${testsDirectory}/${folder}/${file}', !partial, debug);
                    } catch (e: Dynamic) {
                        trace('Error testing $folder/$file at transcript line $lastTranscriptLine: $e');
                        LogUtil.prettyPrintStack(CallStack.exceptionStack());
                        Assert.fail();
                    }
#end
                }
            }
        }
    }

    var lastTranscriptLine = 0;

    private function validateAgainstTranscript(storyFile: String, transcriptFile: String, fullTranscript: Bool = true, debug: Bool = false) {
        var buffer = HankBuffer.FromFile(transcriptFile, files);
        var transcriptLines = buffer.lines();

        // If the transcript starts with a random seed, make sure the story uses that seed
        var randomSeed = null;
        if (transcriptLines[0].startsWith('@')) {
            randomSeed = Std.parseInt(transcriptLines[0].substr(1));
            transcriptLines.remove(transcriptLines[0]);
        }

        var story: Story = null;

// It's easier to debug exceptions on web if they travel up the stack
#if !sys
        story = Story.FromFile(storyFile, files, randomSeed);
#else
        try {
            story = Story.FromFile(storyFile, files, randomSeed);
        } catch (e: Dynamic) {
            trace('Error parsing $storyFile: $e');
            LogUtil.prettyPrintStack(CallStack.exceptionStack());
            Assert.fail();
            return;
        }
#end

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