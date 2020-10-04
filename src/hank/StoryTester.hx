package hank;

import hiss.HissReader;
import hiss.HissTools;
import hiss.StaticFiles;
using StringTools;

class StoryTester implements StoryTeller {
    var transcriptLines: Array<String>;

    public function new(testTranscript: String) {
        transcriptLines = StaticFiles.getContent(testTranscript).split("\n").map(StringTools.trim).filter((s) -> s.length > 0);
    }

    public function handleOutput(text: String, finished: (Int) -> Void) {
        var expected = transcriptLines.shift();
        if (expected != text) throw 'expected "$expected" but output was "$text"';
        finished(0);
    }

    public function handleChoices(choices: Array<String>, choose: (Int) -> Void) {
        for (choice in choices) {
            var expected = transcriptLines.shift().substr(1).trim(); // clip the *
            if (expected != choice) throw 'expected choice "$expected" but it was "$choice"';
        }
        choose(Std.parseInt(transcriptLines.shift().substr(1).trim()) - 1);
    }
}