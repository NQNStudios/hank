package hank;

import hiss.HTypes;
import hiss.CCInterp;
import hiss.StaticFiles;
using hiss.HissTools;

class Story {
    var teller: StoryTeller;
    var interp: CCInterp;
    var storyScript: String;

    public function new(storyScript: String, storyTeller: StoryTeller) {
        StaticFiles.compileWith("reader-macros.hiss");
        StaticFiles.compileWith("hanklib.hiss");

        this.storyScript = storyScript;
        teller = storyTeller;

        interp = new CCInterp();
        
        interp.importFunction(storyTeller, storyTeller.handleOutput, "*handle-output*");
        interp.importFunction(storyTeller, storyTeller.handleChoices, "*handle-choices*");

        interp.load("hanklib.hiss");
    }

    public function run() {
        interp.load("reader-macros.hiss");

        var storyCode = interp.readAll(StaticFiles.getContent(storyScript));
        
        String("Main logic:").message();
        storyCode.print();

        String("").message();
        String("").message();
        String("").message();


        interp.eval(Symbol("begin").cons(storyCode));
    }
}