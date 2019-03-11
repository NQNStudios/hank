package hank;

import haxe.ds.Option;

/**
 A position in a FileBuffer, used for debugging.
**/
typedef Position = {
    var file: String;
    var line: Int;
    var column: Int;
}

/**
 Helper class for reading/parsing information from a file.
**/
class FileBuffer {
    var path: String;
    var buffer: String;
    var line: Int = 1;
    var column: Int = 0;

    public function new(path: String) {
        buffer = sys.io.File.getContent(path);
        this.path = path;
    }

    public function position(): Position {
        return {
            file: path,
            line: line,
            column: column
        };
    }

    /** Peek through the buffer until encountering one of the given terminator sequences **/
    public function peekUntil(terminators: Array<String>): Option<String> {
        var index = buffer.length;

        for (terminator in terminators) {
            var nextIndex = buffer.indexOf(terminator);
            index = nextIndex < index ? nextIndex : index;
        }

        return if (index < buffer.length) {
            Some(buffer.substr(0, index));
        } else {
            None;
        }
    }

    /**
     Drop the given string from the front of buffer, updating the current position
    **/
    function drop(s: String) {
        var lines = s.split('\n');
        if (lines.length > 1) {
            line += lines.length - 1;
            column = lines[lines.length -1].length;
        } else {
            column += lines[lines.length-1].length;
        }
        buffer = buffer.substr(s.length);
    }

    /** Take data from the file until encountering one of the given terminator sequences. **/
    public function takeUntil(terminators: Array<String>, dropTerminator = true): Option<String> {
        return switch (peekUntil(terminators)) {
            case Some(s):
                // Remove the desired data from the buffer
                drop(s);

                // Remove the terminator that followed the data from the buffer
                var nextTerminator = '';
                for (terminator in terminators) {
                    if (buffer.indexOf(terminator) == 0) {
                        drop(terminator);
                        break;
                    }
                }

                // Return the desired data
                Some(s);
            case None:
                None;
        }
    }
}