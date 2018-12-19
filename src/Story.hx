package src;

class Story {
    private var scriptLines: Array<String>;
    private var currentLine: Int = 0;

    public function new(storyFile: String) {
        // TODO open the file
        scriptLines = sys.io.File.getContent(storyFile).split('\n');
    }

    public function currentFrame(): StoryFrame {
        return if (currentLine > scriptLines.length) {
            Empty;
        } else {
            processNextLine();
        }
    }

    private function processNextLine(): StoryFrame {
        currentLine += 1;
        return processLine(scriptLines[currentLine]);
    }

    private function processLine (line: String): StoryFrame {
        var trimmedLine = StringTools.ltrim(line);
        if (trimmedLine.indexOf("INCLUDE ") == 0) {
            var includeFile = trimmedLine.split(" ")[1];

            var includedLines = sys.io.File.getContent(includeFile).split("\n");

            for (i in 0...includedLines.length) {
                scriptLines.insert(currentLine + i + 1, includedLines[i]);
            }

            // Control flows to the first line of the included file
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
