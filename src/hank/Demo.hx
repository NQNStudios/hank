package hank;

import hiss.HissRepl;
import hiss.HissReader;
import hiss.HissTools;
import hiss.StaticFiles;

class Demo implements StoryTeller {
    public static function main() {
        StaticFiles.compileWithAll("examples");

        // TODO ask the user to choose an example
        new Story("examples/hello.hank", new Demo()).run();
    }

    public function new() {
        
    }

    public function handleOutput(text: String) {
        trace(text);
    }

    public function handleChoices(choices: Array<String>) {

    }
}