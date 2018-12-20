package src;

import hscript.Parser;
import hscript.Interp;

class Story {
    private var scriptLines: Array<String>;
    private var currentLine: Int = 0;
    private var directory: String = "";
    private var parser = new Parser();
    private var interp = new Interp();
    // TODO use interp.set(name, value) to share things to script scope

    public function new(storyFile: String) {
        if (storyFile.lastIndexOf("/") != -1) {
            directory = storyFile.substr(0, storyFile.lastIndexOf("/")+1);
        }

        scriptLines = sys.io.File.getContent(storyFile).split('\n');
    }

    public function nextFrame(): StoryFrame {
        return if (currentLine >= scriptLines.length) {
            Empty;
        } else {
            processNextLine();
        }
    }

    private function processHaxeStatement(line: String) {
        // In order to preserve the values of variables declared in embedded Haxe,
        // we need to predeclare them all as globals in this Story's interpreter.
        var trimmed = StringTools.ltrim(line);
        if (trimmed.length > 0) {
            if (StringTools.startsWith(trimmed, "var")) {
                var varName = trimmed.split(" ")[1];
                interp.variables[varName] = null;
                trimmed = trimmed.substr(4); // Strip out the `var ` prefix before executing so the global value doesn't get overshadowed by a new declaration
            }
            var program = parser.parseString(trimmed);
            interp.execute(program);
        }
    }

    private function processNextLine(): StoryFrame {
        var frame = processLine(scriptLines[currentLine]);
        //trace('next line is: ${scriptLines[currentLine+1]}');
        return frame;
    }

    private function processLine (line: String): StoryFrame {
        //trace('processing: ${line}');
        var trimmedLine = StringTools.ltrim(line);
        if (trimmedLine.indexOf("INCLUDE ") == 0) {
            var includeFile = trimmedLine.split(" ")[1];

            var includedLines = sys.io.File.getContent(directory + includeFile).split("\n");

            for (i in 0...includedLines.length) {
                scriptLines.insert(currentLine + i + 1, includedLines[i]);
            }
            scriptLines.insert(currentLine+includedLines.length+1, "EOF");

            // Control flows to the first line of the included file
            currentLine += 1;
            return processNextLine();
        }
        // When encountering a section declaration, skip to the end of the file.
        else if (trimmedLine.indexOf("==") == 0) {
            do {
                currentLine += 1;
            } while (scriptLines[currentLine] != "EOF" && currentLine < scriptLines.length);

            currentLine += 1;
            return processNextLine();
        }
        else if (trimmedLine.indexOf("->") == 0) {
            var nextSection = trimmedLine.split(" ")[1];
            return gotoSection(nextSection);
        } else if (trimmedLine.indexOf("~") == 0) {
            var scriptLine = trimmedLine.substr(1);
            processHaxeStatement(scriptLine);
            currentLine += 1;
            return processNextLine();
        }


        // If the line is none of these special cases, it is just a text line. Remove the comments and evaluate the hscript.

        // Remove line comments
        if (line.indexOf("//") != -1) {
            line = line.substr(0, line.indexOf("//"));
        }

        // Remove block comments
        while (true) {
            var startIdx = line.indexOf("/*");
            var endIdx = line.indexOf("*/");

            if (startIdx != -1 && endIdx > startIdx) {
                line = line.substr(0, startIdx) + line.substr(endIdx+2);
            } else {
                break;
            }
        }

        return if (line.length > 0) {
            // Parse haxe expressions in the text

            while (true) {
                var startIdx = line.indexOf("{");
                var endIdx = line.indexOf("}");

                if (startIdx != -1 && endIdx > startIdx) {
                    var expression = parser.parseString(line.substr(startIdx+1,endIdx-startIdx-1));
                    line = line.substr(0, startIdx) + Std.string(interp.expr(expression)) + line.substr(endIdx+1);
                } else {
                    break;
                }
            }

            currentLine += 1;
            HasText(line);
        } else {
            // Skip empty lines.
            currentLine += 1;
            processNextLine();
        }
    }

    public function gotoSection(section: String): StoryFrame {
        // TODO track view counts as variables. This will require preprocessing script lines to set 0-value section variables 
        for (line in 0...scriptLines.length) {
            if (scriptLines[line] == "== " + section) {
                currentLine = line;
            }
        }
        currentLine += 1;
        return processNextLine();
    }
}
