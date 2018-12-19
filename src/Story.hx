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
            processLine(scriptLines[currentLine]);
        }
    }

    public function processLine (line: String): StoryFrame {
        return HasText(line);
    }

    public function gotoSection(section: String) {
        for (line in 0...scriptLines.length) {
            if (scriptLines[line] == "== " + section) {
                currentLine = line;
            }
        }
    }
}
