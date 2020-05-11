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
    }

    public function run() {
        hissRepl.load("reader-macros.hiss");

        hissRepl.interp.print(Atom(String("For debug purposes, it reads as:")));
        hissRepl.interp.print(hissRepl.readAll(StaticFiles.getContent(storyScript)));
        hissRepl.interp.print(Atom(String("")));

        switch (hissRepl.load(storyScript)) {
            case Signal(Error(s)):
                throw s;
            default:
        }
    }
}