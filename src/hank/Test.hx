package hank;

import hiss.HissRepl;
import hiss.HissReader;
import hiss.HissTools;

class Test {
    public static function main() {
        trace ("Running Hank examples!");

        var exampleDir = 'src/hank/examples/';
        for (file in sys.FileSystem.readDirectory(exampleDir)) {
            var repl = new HissRepl();
            repl.load('src/hank/hank.hiss');

            var path = haxe.io.Path.join([exampleDir, file]).toString();
            trace('Reading $file:');
            trace(HissTools.toPrint(repl.read(sys.io.File.getContent(path))));
            trace('Running $file:');
            trace(repl.load(path));
        }
    }
}