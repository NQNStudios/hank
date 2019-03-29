package tests;

import haxe.CallStack;
using StringTools;
import utest.Assert;

class StoryTest extends hank.StoryTestCase {
    function testAllExamples() {
        var exampleFolders = sys.FileSystem.readDirectory('examples');

        // Iterate through every example in the examples folder
        for (folder in exampleFolders) {
            trace('Running tests for example "${folder}"');
            var files = sys.FileSystem.readDirectory('examples/${folder}');

            for (file in files) {
                if (file.endsWith('.hlog')) {

                    var disabled = file.indexOf("disabled") != -1;
                    var debug = file.indexOf("debug") != -1;
                    var partial = file.indexOf("partial") != -1;
                    if (!disabled) {
                        trace('    Running ${file}');
                        try {
                            validateAgainstTranscript('examples/${folder}/main.hank', 'examples/${folder}/${file}', !partial);
                        } catch (e: Dynamic) {
                            trace('Error testing $folder/$file: $e');
                            trace(CallStack.exceptionStack());
                            Assert.fail();
                        }
                    }
                }
            }
        }
    }
}