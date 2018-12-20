package src;

import hscript.Parser;
import hscript.Interp;

class Story {
    private var scriptLines: Array<String>;
    private var currentLine: Int = 0;
    private var directory: String = "";
    private var parser = new Parser();
    private var interp = new Interp();
    // TODO use interp.set(name, value) to share things (i.e. modules) to script scope

    private var choicesFullText = new Array<String>();

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
        } else if (trimmedLine.indexOf("*") == 0 || trimmedLine.indexOf("+") == 0) {
            var depth = depthOf(trimmedLine);
            var choices = collectChoices(depth);

            return HasChoices(choices);
        }

        // If the line is none of these special cases, it is just a text line. Remove the comments and evaluate the hscript.

        // Remove line comments
        if (line.indexOf("//") != -1) {
            line = line.substr(0, line.indexOf("//"));
        }

        // Remove block comments
        while (Util.containsEnclosure(line, "/*", "*/")) {
            line = Util.replaceEnclosure(line, "", "/*", "*/");
        }

        return if (line.length > 0) {
            line = fillHExpressions(line);

            currentLine += 1;
            HasText(line);
        } else {
            // Skip empty lines.
            currentLine += 1;
            processNextLine();
        }
    }

    /**
    Parse haxe expressions in the text
    **/
    function fillHExpressions(text: String) {
        while (Util.containsEnclosure(text, "{", "}")) {
            var expression = Util.findEnclosure(text,"{","}");
            trace(expression);
            var parsed = parser.parseString(expression);
            text = Util.replaceEnclosure(text, Std.string(interp.expr(parsed)), "{", "}");
        }
        return text;
    }

    public function choose(index: Int): String {
        var choiceDisplayText = choicesFullText[index];
        // TODO remove the contents of the brackets, interpolate expressions in, etc.
        // TODO set the current line to the line following this choice. Set the current depth to that depth 
        

        // When a * or - choice is chosen, remove its line from scriptLines so it doesn't appear again
        // Update the current index to reflect the removed line

        // Stop storing the full text of these choices so we don't accidentally trigger them later.
        choicesFullText = new Array<String>();

        return choiceDisplayText;
    }
    /**
    Handle choice declarations starting at the current script line
    **/
    function collectChoices(depth: Int): Array<String> {
        var choices = new Array<String>();
        var l = currentLine;
        // Scan for more choices in this set  until hitting a new section declaration or TODO a gather. (n hyphens repeated where n=choice depth.) or TODO EOF.  
        while (!StringTools.startsWith(StringTools.ltrim(scriptLines[l]), "==")) {
            // Skip text on a line following a choice. That text is the outcome of the choice.
            if (depthOf(scriptLines[l]) == -1) {
                continue;
            }

            // Skip choices with a different number of *, or +.
            else if (depthOf(scriptLines[l]) == depth) {
                var choiceFullText = scriptLines[l];
                var choiceWithSymbol = StringTools.ltrim(scriptLines[l]);
                var choiceWithoutSymbol = choiceWithSymbol.substr(depthOf(scriptLines[l]));
                choiceWithoutSymbol = StringTools.ltrim(choiceWithoutSymbol);
                // check the choice's flag. Skip choices whose flag is not truthy.
                if (Util.startsWithEnclosure(choiceWithoutSymbol, "{","}")) {
                    var conditionExpression = Util.findEnclosure(choiceWithoutSymbol, "{", "}");
                    trace(conditionExpression);
                    var parsed = parser.parseString(conditionExpression);
                    var conditionValue = interp.expr(parsed);

                    if (!conditionValue) {
                        l += 1;
                        continue;
                    }
                }

                // Keep the contents of brackets but drop what follows
                if (Util.containsEnclosure(choiceWithoutSymbol, "[", "]")) {
                    var contents = Util.findEnclosure(choiceWithoutSymbol, "[", "]");
                    choiceWithoutSymbol = choiceWithoutSymbol.substr(0, choiceWithoutSymbol.indexOf("[")) + contents;
                }

                // Insert haxe expression results into choice text.  
                choiceWithoutSymbol = fillHExpressions(choiceWithoutSymbol);
                choices.push(choiceWithoutSymbol);
                // Store choice's full text so we can uniquely find it in the script and process its divert
                choicesFullText.push(choiceFullText);
            }
            l += 1;
        }

        return choices;
    }

    function depthOf(choice: String): Int {
        var trimmed = StringTools.ltrim(choice);
        return Math.floor(Math.max(trimmed.lastIndexOf("*"), trimmed.lastIndexOf("+")))+1;
    }

    public function gotoSection(section: String): StoryFrame {
        // TODO this should clear the current choice depth
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
