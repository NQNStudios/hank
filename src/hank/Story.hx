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
        
        interp.importFunction(storyTeller.handleOutput, "*handle-output*");

        interp.load("hanklib.hiss");
    }

    public function run() {
        interp.load("reader-macros.hiss");

        String("For debug purposes, it reads as:").print();
        interp.readAll(StaticFiles.getContent(storyScript)).print();

        interp.load(storyScript);
    }
}