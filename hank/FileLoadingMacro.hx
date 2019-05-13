package hank;

using StringTools;

import haxe.macro.Context;
import haxe.macro.Expr;
import hank.HankBuffer;
 
class FileLoadingMacro {
    public static macro function build(files: Array<String>): Array<Field> {
        var fields = Context.getBuildFields();

        var i = 0;
        while (i < files.length) {
            var file = files[i];
            if (file.endsWith("/")) {
                files.remove(file);

                files = files.concat(recursiveLoop(file));
            } else {
                ++i;
            }
        }

        var loadedFiles = [for (file in files) macro $v{file} => $v{sys.io.File.getContent(file)}];

        var filesField = {
            name: "files",
            doc: null,
            meta: [],
            access: [AStatic, APrivate],
            kind: FVar(macro : Map<String, String>, macro $a{loadedFiles}),
            pos: Context.currentPos()
        };

        var bufferFunction = {
            name: "fileBuffer",
            doc: null,
            meta: [],
            access: [AStatic, APrivate],
            kind: FVar(macro : String -> hank.HankBuffer, macro function (path) { return new hank.HankBuffer(path, files[path]);}),
            pos: Context.currentPos()
        }

        fields.push(filesField);
        fields.push(bufferFunction);
        return fields;
    }

    // this function is nabbed from https://code.haxe.org/category/beginner/using-filesystem.html
    static function recursiveLoop(directory:String, ?files: Array<String>): Array<String> {
        if (files == null) files = [];
        if (sys.FileSystem.exists(directory)) {
            trace("directory found: " + directory);
            for (file in sys.FileSystem.readDirectory(directory)) {
                var path = haxe.io.Path.join([directory, file]);
                if (!sys.FileSystem.isDirectory(path)) {
                    trace("file found: " + path);
                    // do something with file
                    files.push(path.toString());
                } else {
                    var directory = haxe.io.Path.addTrailingSlash(path);
                    trace("directory found: " + directory);
                    files = recursiveLoop(directory, files);
                }
            }
        } else {
            trace('"$directory" does not exists');
        }

        return files;
    }
}