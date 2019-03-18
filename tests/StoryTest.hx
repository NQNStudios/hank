package tests;

class StoryTest extends hank.StoryTestCase {
    function testAllExamples() {
        var exampleFolders = sys.FileSystem.readDirectory('examples');

        // Iterate through every example in the examples folder
        for (folder in exampleFolders) {
            trace('Running tests for example "${folder}"');
            var files = sys.FileSystem.readDirectory('examples/${folder}');

            for (file in files) {
                if (StringTools.endsWith(file, '.hlog')) {
                    trace('    Running ${file}');

                    var disabled = file.indexOf("disabled") != -1;
                    var debug = file.indexOf("debug") != -1;
                    var partial = file.indexOf("partial") != -1;
                    if (!disabled) {
                        validateAgainstTranscript('examples/${folder}/main.hank', 'examples/${folder}/${file}', !partial);
                    }
                }
            }
        }
    }
}