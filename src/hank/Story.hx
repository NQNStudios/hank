package hank;

import hiss.HTypes;
import hiss.CCInterp;
import hiss.StaticFiles;
import hiss.HissReader;
import hiss.HStream;
using hiss.HissTools;

class Story {
    var teller: StoryTeller;
    var interp: CCInterp;
    var storyScript: String;
    // Separate reader for Hiss expressions:
    var reader: HissReader;

    function hissRead(str: String) {
        return reader.read("", HStream.FromString(str));
    }

    public function new(storyScript: String, storyTeller: StoryTeller) {
        StaticFiles.compileWith("reader-macros.hiss");
        StaticFiles.compileWith("hanklib.hiss");

        this.storyScript = storyScript;
        teller = storyTeller;

        interp = new CCInterp();
        reader = new HissReader(interp); // It references the same CCInterp but has its own readtable

        interp.importFunction(storyTeller, storyTeller.handleOutput, "*handle-output*");
        interp.importFunction(storyTeller, storyTeller.handleChoices, "*handle-choices*");
        interp.importFunction(this, hissRead, "hiss-read");
        interp.importFunction(reader, reader.readDelimitedList, "hiss-read-delimited-list", List([Int(3)]) /* keep blankELements wrapped */, ["terminator", "delimiters", "start", "stream"]);

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