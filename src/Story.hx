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

    private var choiceDepth = 0;
    private var choicesFullText = new Array<String>();
    private var debugPrints: Bool;

    private function debugTrace(v: Dynamic, ?infos: haxe.PosInfos) {
        if (debugPrints) {
            trace(v, infos);
        }
    }

    public function new(storyFile: String, debug: Bool = false) {
        debugPrints = debug;
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
        //debugTrace('next line is: ${scriptLines[currentLine+1]}');
        return frame;
    }

    private function processLine (line: String): StoryFrame {
        debugTrace('processing: ${line}');
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
            if (depth == choiceDepth + 1) {
                choiceDepth = depth;
                var choices = collectChoices(depth);

                return HasChoices(choices);
            } else if (depth == choiceDepth) {
                debugTrace('${trimmedLine} causing skipping to gather');
                return skipToGather();
            }
        } else if (choiceDepth >= 1 && trimmedLine.indexOf(StringTools.lpad("", "-", choiceDepth)) == 0) {
            // Don't do anything if this line is the gather from a set of choices we just left
            currentLine += 1;
            return processLine(trimmedLine.substr(choiceDepth));
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
            HasText(StringTools.ltrim(line));
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
            // debugTrace(expression);
            var parsed = parser.parseString(expression);
            text = Util.replaceEnclosure(text, Std.string(interp.expr(parsed)), "{", "}");
        }
        return text;
    }

    public function choose(index: Int): String {
        if (choicesFullText.length == 0) {
            trace("Error! Trying to choose when no choices are available!");
        }
        debugTrace('At the start: ${choicesFullText.toString()}');
        var choiceDisplayText = choicesFullText[index];
        debugTrace('Choosing: ${choiceDisplayText}');
        choiceDisplayText = StringTools.ltrim(StringTools.ltrim(choiceDisplayText).substr(choiceDepth));

        // Remove initial condition 
        if (Util.startsWithEnclosure(choiceDisplayText, "{","}")) {
            choiceDisplayText = StringTools.ltrim(Util.replaceEnclosure(choiceDisplayText, "", "{", "}"));
        }
        // remove the contents of the brackets,
        if (Util.containsEnclosure(choiceDisplayText, "[", "]")) {
            choiceDisplayText = Util.replaceEnclosure(choiceDisplayText, "", "[", "]");
        }
        // interpolate expressions in, etc.
        choiceDisplayText = fillHExpressions(choiceDisplayText);

        // set the current line to the line following this choice. Set the current depth to that depth 
        var nextLine = findNextLineAfterChoice(index);
        currentLine = nextLine;
        choiceDepth = depthOf(choicesFullText[index]);

        // When a * choice is chosen, remove its line from scriptLines so it doesn't appear again
        // Update the current index to reflect the removed line
        if (StringTools.startsWith(StringTools.ltrim(choicesFullText[index]), "*")) {
            // debugTrace('Length: ${scriptLines.length}');
            // debugTrace('indexOf: ${scriptLines.indexOf(choicesFullText[index])}');
            scriptLines.remove(choicesFullText[index]);
            // debugTrace('Length: ${scriptLines.length}');
            if (currentLine > index) currentLine -= 1;
        }

        // Stop storing the full text of these choices so we don't accidentally trigger them later.
        choicesFullText = new Array<String>();
        debugTrace('After clearing: ${choicesFullText.toString()}');

        return choiceDisplayText;
    }

    function skipToGather() {
        debugTrace('depth: ${choiceDepth}');
        var gatherOfThisDepth = StringTools.lpad("", "-", choiceDepth);
        var l = currentLine+1;
        var foundIt = false;
        debugTrace(l);
        debugTrace(scriptLines[l]);
        while (l < scriptLines.length && scriptLines[l] != "EOF") {
            var trimmed = StringTools.ltrim(scriptLines[l]);
            if (trimmed.length == 0) { 
                l += 1;
                continue;
            }
            if (StringTools.startsWith(StringTools.ltrim(scriptLines[l]), "==")) {
                break;
            }
            if (StringTools.startsWith(trimmed, gatherOfThisDepth)) {
                // -> diverts can trip false gather positives
                var possibleGather = trimmed.substr(0, gatherOfThisDepth.length + 1);
                if (StringTools.endsWith(possibleGather, ">")) {
                    l += 1;
                    continue;
                }
                foundIt = true;
                break;
            }
            l += 1;
        }
        if (foundIt) {
            currentLine = l;
            return processNextLine();
        } else {
            return Empty;
        }

    }

    function findNextLineAfterChoice(choice: Int): Int {
        // The next line is the first line after the choice with no depth (meaning it's plaintext -- unless a different same-depth choice comes first) or a gather of proper depth
        var gatherOfThisDepth = StringTools.lpad("", "-", choiceDepth);
        var choiceLine = scriptLines.indexOf(choicesFullText[choice]);
        // debugTrace('Choice line: ${choiceLine}');
        var l = choiceLine+1;

        var metNextInSet = false;
        var foundIt = false;
        while (l < scriptLines.length && scriptLines[l] != "EOF") {
            var trimmed = StringTools.ltrim(scriptLines[l]);
            if (trimmed.length == 0) { 
                l += 1;
                continue;
            }
            if (StringTools.startsWith(StringTools.ltrim(scriptLines[l]), "==")) {
                break;
            }
            if (!metNextInSet && StringTools.startsWith(trimmed, "->")) {
                foundIt = true;
                break;
            }
            if (StringTools.startsWith(trimmed, gatherOfThisDepth)) {
                // -> diverts can trip false gather positives
                var possibleGather = trimmed.substr(0, gatherOfThisDepth.length + 1);
                if (StringTools.endsWith(possibleGather, ">")) {
                    l += 1;
                    continue;
                }
                foundIt = true;
                break;
            }
            else if (!metNextInSet && depthOf(trimmed) == 0) {
                foundIt = true;
                break;
            }
            else if (!metNextInSet && depthOf(trimmed) == choiceDepth+1) {
                foundIt = true;
                break;
            } else if (depthOf(trimmed) == choiceDepth) {
                debugTrace('${trimmed} is next in set');
                metNextInSet = true;
                l += 1;
                continue;
            }

        }
        if (!foundIt) {
            debugTrace("no next line found!");
            return -1; // Need to throw up an empty frame
        } else {
            debugTrace('Next line is: ${scriptLines[l]}');
            return l;
        }
    }

    /**
    Handle choice declarations starting at the current script line
    **/
    function collectChoices(depth: Int): Array<String> {
        var choices = new Array<String>();
        var l = currentLine;
        // Scan for more choices in this set  until hitting a new section declaration or TODO a gather. (n hyphens repeated where n=choice depth.) or EOF.  
        var gatherOfThisDepth = StringTools.lpad("", "-", depth);
        while (l < scriptLines.length && scriptLines[l] != "EOF" && !StringTools.startsWith(StringTools.ltrim(scriptLines[l]), "==")) {
            var trimmed = StringTools.ltrim(scriptLines[l]);
            // Skip text on a line following a choice. That text is the outcome of the choice.
            if (depthOf(scriptLines[l]) == 0) {
                // debugTrace('Skipping ${scriptLines[l]}');
                l += 1;
                continue;
            }
            // Stop when we hit a gather of this depth

            if (StringTools.startsWith(trimmed, gatherOfThisDepth)) {
                var possibleGather = trimmed.substr(0, gatherOfThisDepth.length + 1);
                if (StringTools.endsWith(possibleGather, ">")) {
                    l += 1;
                    continue;
                }
                else {
                    break;
                }
            }

            // Skip choices with a different number of *, or +.
            else if (depthOf(scriptLines[l]) != depth) {
                // debugTrace('Skipping ${scriptLines[l]}');
                l += 1;
                continue;
            }
            else if (depthOf(scriptLines[l]) == depth) {
                var choiceFullText = scriptLines[l];
                var choiceWithSymbol = StringTools.ltrim(scriptLines[l]);
                var choiceWithoutSymbol = choiceWithSymbol.substr(depthOf(scriptLines[l]));
                choiceWithoutSymbol = StringTools.ltrim(choiceWithoutSymbol);
                // check the choice's flag. Skip choices whose flag is not truthy.
                if (Util.startsWithEnclosure(choiceWithoutSymbol, "{","}")) {
                    var conditionExpression = Util.findEnclosure(choiceWithoutSymbol, "{", "}");
                    var parsed = parser.parseString(conditionExpression);
                    var conditionValue = interp.expr(parsed);

                    if (!conditionValue) {
                        l += 1;
                        continue;
                    }
                    else {
                        // Don't print the flag in the choice list
                        choiceWithoutSymbol = StringTools.ltrim(Util.replaceEnclosure(choiceWithoutSymbol, "", "{", "}"));
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
                debugTrace('collecting choice ${choiceFullText}');
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
        // this should clear the current choice depth
        choiceDepth = 0;
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
