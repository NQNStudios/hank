package hank;

import hscript.Parser;
import hscript.Interp;

/**
 Interface between a Hank story, and its embedded HScript interpreter
**/
class HInterface {
    var parser: Parser = new Parser();
    var interp: Interp = new Interp();

    public function new() {
        // TODO allow constructing the interface with external state variables. These variables should all be serializable so stories can be deterministically replayed
        // TODO although... that excludes something like FlxG. Maybe 2 different pipelines for passing in Haxe objects, one serializable and one not.

    }
}