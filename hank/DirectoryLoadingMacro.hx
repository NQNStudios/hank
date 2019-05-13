package hank;

class DirectoryLoadingMacro {
    public static macro function build(directory: String, recursive: Bool=true): Array<Field> {
        var files = if (recursive) {
            recursiveLoop(directory, []);
        } else {
            sys.FileSystem.readDirectory(directory);
        }

        return FileLoadingMacro.build(files);
    }

    // this function is nabbed from https://code.haxe.org/category/beginner/using-filesystem.html
    static function recursiveLoop(directory:String, files: Array<String>): Array<String> {
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