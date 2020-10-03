package hank;

import hiss.HissReader;
import hiss.HissTools;
import hiss.StaticFiles;

class Demo implements StoryTeller {
    public static function main() {
        StaticFiles.compileWithAll("examples");

        // TODO ask the user to choose an example
        new Story("examples/knots.hank", new Demo()).run();
    }

    public function new() {
        
    }

    public function handleOutput(text: String, finished: (Int) -> Void) {
        Sys.println(text);
        finished(0);
    }

    public function handleChoices(choices: Array<String>, choose: (Dynamic) -> Void) {
        var idx = 1;
        for (choice in choices) {
            Sys.println('${idx++}. ${choice}');
        }
        choose(Std.parseInt(Sys.stdin().readLine()) - 1);
    }
}