package hank;

import hiss.HissReader;
import hiss.HissTools;
import hiss.StaticFiles;

class StoryTellerDemo implements StoryTeller {
    public static function main() {
        StaticFiles.compileWithAll("examples");

        var examples = sys.FileSystem.readDirectory("src/hank/examples");
        var demo = new StoryTellerDemo();
        var debug = false;
        #if debug
        debug = true;
        #end

        demo.handleChoices(examples, (index) -> {
            new Story("examples/" + examples[index] + "/main.hank", demo, debug).run();
        });
    }

    public function new() {
        
    }

    public function handleOutput(text: String, finished: (Int) -> Void) {
        Sys.println(text);
        finished(0);
    }

    public function handleChoices(choices: Array<String>, choose: (Int) -> Void) {
        var idx = 1;
        for (choice in choices) {
            Sys.println('${idx++}. ${choice}');
        }
        choose(Std.parseInt(Sys.stdin().readLine()) - 1);
    }
}