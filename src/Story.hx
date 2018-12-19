package src;

class Story {
    private var scriptLines: Array<String>;
    private var currentLine: Int = 0;
    private var directory: String = "";

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

            // Control flows to the first line of the included file
            currentLine += 1;
            return processNextLine();
        }
        else if (trimmedLine.indexOf("->") == 0) {
            var nextSection = trimmedLine.split(" ")[1];
            return gotoSection(nextSection);
        }

        return HasText(line);
    }

    public function gotoSection(section: String): StoryFrame {
        for (line in 0...scriptLines.length) {
            if (scriptLines[line] == "== " + section) {
                currentLine = line;
            }
        }
        return processNextLine();
    }
}
