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
        trace('Lines: ${scriptLines.length}');
    }

    public function nextFrame(): StoryFrame {
        return if (currentLine >= scriptLines.length) {
            Empty;
        } else {
            processNextLine();
        }
    }

    private function processNextLine(): StoryFrame {
        var frame = processLine(scriptLines[currentLine]);
        currentLine += 1;
        trace('next line is: ${scriptLines[currentLine]}');
        return frame;
    }

    private function processLine (line: String): StoryFrame {
        trace('processing: ${line}');
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
            var scriptLine = trimmedLine.substr(trimmedLine.indexOf("~")+1);
            var program = parser.parseString(scriptLine);
            interp.execute(program);
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

        // Skip empty lines.
        return if (line.length > 0) {
            HasText(line);
        } else {
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
