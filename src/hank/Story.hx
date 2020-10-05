package hank;

import hiss.HTypes;
import hiss.CCInterp;
import hiss.StaticFiles;
import hiss.HissReader;
import hiss.HStream;
import hiss.HissTools;
using hiss.HissTools;
using StringTools;

class Story {
    var teller: StoryTeller;
    var interp: CCInterp;
    var storyScript: String;
    // Separate reader for Hiss expressions:
    var reader: HissReader;
    var debug: Bool;

    function hissRead(str: String) {
        return reader.read("", HStream.FromString(str));
    }

    function debugPrint(val: HValue) {
        return if (debug) val.print() else val;
    }

    public function new(storyScript: String, storyTeller: StoryTeller, debug = false) {
        this.debug = debug;

        StaticFiles.compileWith("reader-macros.hiss");
        StaticFiles.compileWith("hanklib.hiss");

        this.storyScript = storyScript;
        teller = storyTeller;
    }

    public function run() {
        // TODO make a way to do all this loading before calling run(), but still make sure all the loading happens if it hasn't:
        interp = new CCInterp();
        reader = new HissReader(interp); // It references the same CCInterp but has its own readtable

        interp.importFunction(teller, teller.handleOutput, "*handle-output*");
        interp.importFunction(teller, teller.handleChoices, "*handle-choices*");
        interp.importFunction(this, hissRead, "hiss-read");
        interp.importFunction(reader, reader.readDelimitedList, "hiss-read-delimited-list", List([Int(3)]) /* keep blankELements wrapped */, ["terminator", "delimiters", "start", "stream"]);

        interp.importFunction(this, debugPrint, "print", T);

        interp.load("hanklib.hiss");
        interp.load("reader-macros.hiss");

        var storyCode = interp.readAll(StaticFiles.getContent(storyScript));
        
        // This has to happen AFTER reading the story, for (while) reasons
        interp.truthy = (value) -> switch (value) {
            case Nil: false;
            case List([]): false;
            case Int(0): false;
            case String(""): false;
            default: true;
        };

        if (debug) {
            String("Main logic:").message();
            storyCode.print();

            String("").message();
            String("").message();
            String("").message();
        }

        stackSafeEval(Symbol("begin").cons(storyCode));
    }

    function stackSafeEval(exp: HValue) {
        try {
            interp.eval(exp);
        } catch (nextExp: String) {
            if (nextExp.startsWith("STACK-UNWIND")) {
                stackSafeEval(hissRead(nextExp.substr(13)));
            } else {
                throw nextExp;
            }
        }
    }
}