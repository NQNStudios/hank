package hank;

import hiss.HTypes;
import hiss.HissRepl;
import hiss.StaticFiles;

class Story {
    var teller: StoryTeller;
    var hissRepl: HissRepl;
    var storyScript: String;

    public function new(storyScript: String, storyTeller: StoryTeller) {
        StaticFiles.compileWith("reader-macros.hiss");
        StaticFiles.compileWith("hanklib.hiss");

        this.storyScript = storyScript;
        teller = storyTeller;


        hissRepl = new HissRepl();
        
        hissRepl.interp.set("*handle-output*", Function(Haxe(Fixed, function(text: HValue) {
            storyTeller.handleOutput(text.toString());
            return Nil;
        }, "*handle-output*")));

        hissRepl.load("hanklib.hiss");

        hissRepl.load("reader-macros.hiss");
    }

    public function run() {
        hissRepl.load(storyScript);
    }
}