package src;

import haxe.ds.Option;
import haxe.io.Bytes;

// TODO sys.io.File calls might not work on HTML5 targets
import sys.io.FileOutput;

import hscript.Parser;
import hscript.Interp;

typedef HankLine = {
    var sourceFile: String;
    var lineNumber: Int;
    var type: LineType;
}

typedef Choice = {
    var expires: Bool;
    var text: String;
    var depth: Int;
    var id: Int;
}

enum LineType {
    IncludeFile(path: String);
    OutputText(text: String);
    // Choices are parsed with a unique ID so they can be followed even if duplicate text is used for multiple choices
    DeclareChoice(choice: Choice);
    DeclareSection(name: String);
    DeclareSubsection(name: String);
    Divert(target: String);
    Gather(depth: Int, restOfLine: LineType);
    HaxeLine(code: String);
    HaxeBlock(lines: Int, code: String);
    BlockComment(lines: Int);
    Empty;
}

@:allow(tests.StoryTest)
class Story {
    private var lineCount: Int = 0;
    private var scriptLines: Array<HankLine> = new Array();
    private var currentLine: Int = 0;
    private var directory: String = "";
    private var parser = new Parser();
    private var interp = new Interp();
    // TODO use interp.set(name, value) to share things (i.e. modules) to script scope
    // TODO can objects be shared in/out of HScript?
    private var transcriptFile: Option<FileOutput> = None;

    private var choiceDepth = 0;
    private var debugPrints: Bool;
    // Count how many choices have been parsed so each one can have a unique ID
    private var choicesParsed = 0;

    private function debugTrace(v: Dynamic, ?infos: haxe.PosInfos) {
        if (debugPrints) {
            trace(v, infos);
        }
    }

    private function closeTranscript() {
        switch (transcriptFile) {
            case Some(file):
                file.close();
            default:
        }
    }

    private function logFrameToTranscript(frame: StoryFrame) {
        switch (frame) {
            case HasText(text):
                logToTranscript(text);
            case HasChoices(choices):
                for (choice in choices) {
                    logToTranscript('* ${choice}');
                }
            case Error(message):
                logToTranscript('! ${message}');
                closeTranscript();
            case Finished:
                closeTranscript();
        }
    }

    private function logToTranscript(line: String) {
        switch (transcriptFile) {
            case Some(file):
                file.write(Bytes.ofString(line + "\n"));
            default:
        }
    }

    /**
    Create a new Story processor.
    @param debug Whether to output debug information to stdout
    @param transcriptPath an optional filepath to output a transcript of the story playthrough
    **/
    public function new(debug: Bool = false, transcriptPath="") {
        debugPrints = debug;
        if (transcriptPath.length > 0) {
            transcriptFile = Some(sys.io.File.write(transcriptPath));
        }
    }

    var rootFile = "";

    /**
    Pre-parse a Hank script for execution. Nothing will be evaluated, and INCLUDEd files are not parsed until the script encounters them.
    **/
    public function loadScript(storyFile: String, includedScript = false) {
        if (!includedScript) {
            rootFile = storyFile;
            if ( storyFile.lastIndexOf("/") != -1) { 
                directory = storyFile.substr(0, storyFile.lastIndexOf("/")+1);
            }
        } 

        parseScript(storyFile);
    }

    private function parseLine(line: String, rest: Array<String>): LineType {
        var trimmedLine = StringTools.trim(line);

        // Remove line comments from the line
        if (trimmedLine.indexOf("//") != -1) {
            trimmedLine = trimmedLine.substr(0, trimmedLine.indexOf("//"));
        }
        // Remove block comments from the line
        while (Util.containsEnclosure(trimmedLine, "/*", "*/")) {
            trimmedLine = Util.replaceEnclosure(trimmedLine, "", "/*", "*/");
        }

        if (trimmedLine.length > 0) {
            // INCLUDEd scripts must be parsed immediately because the writer may expect section viewcounts for included sections to be 0 and not null
            if (StringTools.startsWith(trimmedLine, "INCLUDE")) {
                var fullPath = directory + StringTools.trim(trimmedLine.substr(8));
                loadScript(fullPath, true);
                return IncludeFile(fullPath);
            }
            // Parse a section or subsection declaration
            else if (StringTools.startsWith(trimmedLine, "=")) {
                var equals_signs = 1;
                while (trimmedLine.charAt(equals_signs) == trimmedLine.charAt(equals_signs-1)) {
                    equals_signs += 1;
                }

                // Allow missing space i.e. ==section
                var sectionName = StringTools.trim(trimmedLine.substr(equals_signs));

                // Allow format == section ==
                sectionName = sectionName.split(" ")[0];

                // Initialize its view count variable to 0
                // TODO if it's a stitch, prefix the count variable with section name (this will be tough because the . operator is already defined and we want the main section to be an int view count, not a dictionary of its stiches)
                interp.variables[sectionName] = 0;

                switch (equals_signs) {
                    // Stitches declared like = stitch
                    case 1:
                        return DeclareSubsection(sectionName);
                    // Technically, ======= also works
                    default:
                        return DeclareSection(sectionName);
                }
            } else if (StringTools.startsWith(trimmedLine, "->")) {
                return Divert(StringTools.trim(trimmedLine.substr(2)));
            } else if (StringTools.startsWith(trimmedLine, "*") || StringTools.startsWith(trimmedLine, "+")) {
                var expires = StringTools.startsWith(trimmedLine, "*");
                var depth = 1;
                while (trimmedLine.charAt(depth) == trimmedLine.charAt(depth-1)) {
                    depth += 1;
                }

                var choiceText = StringTools.trim(trimmedLine.substr(depth));
                return DeclareChoice({
                    expires: expires,
                    text: choiceText,
                    depth: depth,
                    id: choicesParsed++
                    });
            } else if (StringTools.startsWith(trimmedLine,"-")) {
                var gatherDepth = 1;
                while (trimmedLine.charAt(gatherDepth) == trimmedLine.charAt(gatherDepth-1)) {
                    gatherDepth += 1;
                }

                // Gathers store the parsed version of the next line.
                return Gather(gatherDepth, parseLine(trimmedLine.substr(gatherDepth), rest));
            } else if (StringTools.startsWith(trimmedLine, "~")) {
                return HaxeLine(StringTools.trim(trimmedLine.substr(1)));
            } else if (StringTools.startsWith(trimmedLine, "```")) {
                var block = "";
                var lines = 2;
                // Loop until the end of the code block, incrementing the line count every time
                while (!StringTools.startsWith(StringTools.trim(rest[0]), "```")) {
                    // debugTrace(rest[0]);
                    block += rest[0] + '\n';
                    rest.remove(rest[0]);
                    lines += 1;
                }

                return HaxeBlock(lines, block);
            }
            else if(StringTools.startsWith(trimmedLine, "/*")) {
                var lines = 2;
                // Loop until the end of the multiline block comment
                while (!StringTools.endsWith(StringTools.trim(rest[0]), "*/")) {
                    rest.remove(rest[0]);
                    lines += 1;
                }

                return BlockComment(lines);
            }
            else {
                return OutputText(trimmedLine);
            }
        } else {
            return Empty;
        }
    }

    private function parseScript(file: String) {
        var unparsedLines = sys.io.File.getContent(file).split('\n');
        lineCount += unparsedLines.length;

        // Pre-Parse every line in the given file
        var idx = 0;
        while (idx < unparsedLines.length) { 
 
            var parsedLine = {
                sourceFile: file,
                lineNumber: idx+1,
                type: LineType.Empty
            };
            var unparsedLine = unparsedLines[idx];
            parsedLine.type = parseLine(unparsedLine, unparsedLines.slice(idx+1));
            scriptLines.push(parsedLine);

            // Normal lines are parsed alone, but Haxe blocks are parsed as a group, so
            // the index needs to update accordingly 
            switch (parsedLine.type) {
                case HaxeBlock(lines, _):
                    for (i in 0...lines-1) {
                        scriptLines.push({
                            sourceFile: "",
                            lineNumber: 0,
                            type: LineType.Empty
                        });
                    }
                    idx += lines;
                case BlockComment(lines):
                    for (i in 0...lines-1) {
                        scriptLines.push({
                            sourceFile: "",
                            lineNumber: 0,
                            type: LineType.Empty
                        });
                    }
                    idx += lines;
                default:
                    idx += 1;
            }
        }
    }

    private var started = false;
    public function nextFrame(): StoryFrame {
        if (!started) {
            gotoFile(rootFile);
            started = true;
        }
        if (currentLine >= scriptLines.length) {
            return Finished;
        } else {
            var frame = processNextLine();
            logFrameToTranscript(frame);
            return frame;
        }
    }

    // TODO this doesn't allow for multiple declaration (var a, b;) and other edge cases that must exist
    private function processHaxeBlock(lines: String) {
        for (line in lines.split('\n')) {
            // In order to preserve the values of variables declared in embedded Haxe,
            // we need to predeclare them all as globals in this Story's interpreter.
            var trimmed = StringTools.ltrim(line);
            if (trimmed.length > 0) {
                if (StringTools.startsWith(trimmed, "var")) {
                    var varName = trimmed.split(" ")[1];
                    interp.variables[varName] = null;
                    trimmed = trimmed.substr(4); // Strip out the `var ` prefix before executing so the global value doesn't get overshadowed by a new declaration
                }
                debugTrace('Parsing haxe "${trimmed}"');
                var program = parser.parseString(trimmed);
                interp.execute(program);
            }
        }
    }

    private function gotoLine(line: Int) {
        if (line >= 0 && line <= scriptLines.length) {
            currentLine = line;
        } else {
            throw 'Tried to go to out of range line ${line}';
        }

        if (line == scriptLines.length) {
            // Reached the end of the script
            finished = true;
        }
    }

    private function stepLine() {
        if (!finished) {
            // debugTrace('Stepping to line ${Std.string(scriptLines[currentLine+1])}');
            gotoLine(currentLine+1);
        } else {
            throw "Tried to step past the end of a script";
        }
    }

    private function processNextLine(): StoryFrame {
        // debugTrace('line ${currentLine} of ${scriptLines.length}');
        var scriptLine = scriptLines[currentLine];
        var frame = processLine(scriptLine);

        switch (frame) {
            case Error(message):
                var fullMessage = 'Error at line ${scriptLine.lineNumber} in ${scriptLine.sourceFile}: ${message}';
                if (debugPrints) {
                    throw fullMessage;
                } else {
                    // This is a breaking error in production code. Output it to a file
                    trace(fullMessage);

                    return Finished;
                }
            default:
                return frame;
        }
    }

    private var finished: Bool = false;

    private function gotoFile(file: String) {
        for (i in 0...scriptLines.length) {
            if (scriptLines[i].sourceFile == file) {
                gotoLine(i);
                break;
            }
        }
    }

    private var includedFilesProcessed = new Array();

    /** Execute a parsed script statement **/
    private function processLine (line: HankLine): StoryFrame {
        debugTrace('Processing ${Std.string(line)}');

        var file = line.sourceFile;
        var type = line.type;
        switch (type) {
            // Execute text lines by evaluating their {embedded expressions}
            case OutputText(text):
                stepLine();
                return HasText(fillHExpressions(text));

            // Execute include statements by jumping to the start of that file
            case IncludeFile(path):
                if (includedFilesProcessed.indexOf(path) == -1) {
                    includedFilesProcessed.push(path);
                    gotoFile(path);
                } else {
                    stepLine();
                }
                return processNextLine();

            // Execute diverts by following them immediately
            case Divert(target):
                return gotoSection(target);

            // When a new section is declared control flow stops. Skip to the end of the current file
            case DeclareSection(_):
                var nextLineFile = "";
                do {
                    stepLine();
                    nextLineFile = scriptLines[currentLine].sourceFile;
                    // debugTrace(nextLineFile);
                } while (nextLineFile == file);
                // debugTrace('${file} != ${nextLineFile}');
                return processNextLine();

            // Execute haxe lines with hscript
            case HaxeLine(code):
                processHaxeBlock(code);
                stepLine();
                return processNextLine();
            case HaxeBlock(_, code):
                processHaxeBlock(code);
                stepLine();
                return processNextLine();

            // Execute choice declarations by collecting the set of choices and presenting valid ones to the player
            case DeclareChoice(choice):
                if (choice.depth > choiceDepth) {
                    choiceDepth = choice.depth;
                } else if (choice.depth < choiceDepth) {
                    // The lines following a choice have run out. Now we need to look for the following gather
                    return processFromNextGather();
                }
                
                return HasChoices([for (choice in collectChoicesToDisplay()) choice.text]);

            // Execute gathers by updating the choice depth and continuing from that point
            case Gather(depth, nextPartType):
                if (choiceDepth > depth) {
                    choiceDepth = depth;
                    return processLine({
                        lineNumber: currentLine,
                        sourceFile: scriptLines[currentLine].sourceFile,
                        type: nextPartType
                    });
                } else {
                    return Error("Encountered a gather for the wrong depth");
                }

            // Skip comments and empty lines
            default:
                stepLine();
                return processNextLine();
        }
    }

    /**
    Parse and fill haxe expressions in the text based on current variable values
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

    /**
    Make a choice for the player.
    @param index A valid index of the choice list returned by nextFrame()
    @return the choice output.
    **/
    public function choose(index: Int): String {
        var validChoices = collectChoicesToDisplay(true);
        var choiceTaken = validChoices[index];
        choiceDepth = choiceTaken.depth + 1;
        // Remove * choices from scriptLines
        if (choiceTaken.expires) {
            choicesEliminated.push(choiceTaken.id);
        }
        // Find the line where the choice taken occurs
        for (i in currentLine...scriptLines.length) {
            switch (scriptLines[i].type) {
                case DeclareChoice(choice):
                    if (choice.id == choiceTaken.id) {
                        gotoLine(i);
                        break;
                    }
                default:
            }
        }

        // Move to the line following this choice.
        stepLine();

        logToTranscript('>>> ${index}');
        logToTranscript(choiceTaken.text);
        return choiceTaken.text;
    }

    /**
    Search for the next gather that applies to the current choice depth, and follow it.
    **/
    function processFromNextGather(): StoryFrame {
        // debugTrace("called processFromNextGather()");
        var l = currentLine+1;
        var file = scriptLines[currentLine].sourceFile;
        while (l < scriptLines.length && scriptLines[l].sourceFile == file) {
            // debugTrace('checking ${Std.string(scriptLines[l])} for gather');
            switch (scriptLines[l].type) {
                case DeclareSection(_):
                    return Error("Failed to find a gather or divert before the file ended.");
                case Gather(depth, type):
                    gotoLine(l);
                    return processNextLine();
                default:
                    // These are probably lines following the other choices
            }
            
            l += 1;
        }
        return Error("Failed to find a gather or divert before the file ended.");
    }

    /**
    Handle choice declarations starting at the current script line
    **/
    function collectRawChoices(): Array<Choice> {
        var choices = new Array();
        // Scan for more choices in this set until hitting a new section declaration, a gather of the right depth, or the end of this file
        var file = scriptLines[currentLine].sourceFile;
        var nextLineFile = file;
        var l = currentLine;
        while (l < scriptLines.length && scriptLines[l].sourceFile == file) { // check for EOF

            var type = scriptLines[l].type;
            switch (type) {
                // Collect choices of the current depth
                case DeclareChoice(choice):
                    // trace(Std.string(choice));
                    if (choice.depth == choiceDepth) {
                        choices.push({
                            expires: choice.expires,
                            id: choice.id,
                            depth: choice.depth,
                            text: choice.text
                            });
                    }
                // Stop searching when we hit a gather of the current depth
                case Gather(depth,_):
                    if (depth == choiceDepth){
                        break;
                    }
                // Or when we hit a section declaration
                case DeclareSection(_):
                    break;
                default:
            }

            nextLineFile = scriptLines[l++].sourceFile;
            // debugTrace(nextLineFile);
        }

        return choices;
    }

    /**
    Check if a choice's display condition is satisfied
    **/
    private function checkChoiceCondition(choice: Choice): Bool {
        return if (Util.startsWithEnclosure(choice.text, "{", "}")) {
            var conditionExpression = Util.findEnclosure(choice.text, "{", "}");
            var parsed = parser.parseString(conditionExpression);
            var conditionValue = interp.expr(parsed);
            conditionValue;
        } else true;
    }

    /**
    Process a choice into the desired form to show the player
    @param chosen Whether to show the choice's "before" or "after" text to the player
    **/
    private function choiceToDisplay(choice: Choice, chosen: Bool): Choice {
        // Don't display the choice's condition
        if (Util.startsWithEnclosure(choice.text, "{", "}")) {
            choice.text = StringTools.trim(Util.replaceEnclosure(choice.text, "", "{", "}"));
        }
        // Handle bracket hiding
        // If it's been chosen, drop the bracket contents and keep what's next
        if (Util.containsEnclosure(choice.text, "[", "]")) {
            if (chosen) {
                choice.text = Util.replaceEnclosure(choice.text, "", "[", "]");
                // Remove double spaces resulting from this
                choice.text = StringTools.replace(choice.text, "  ", " ");
            } else {
                choice.text = choice.text.substr(0, choice.text.indexOf('[')) + Util.findEnclosure(choice.text, "[", "]");
            }
        }

        choice.text = fillHExpressions(choice.text);
        choice.text = StringTools.trim(choice.text);
        return choice;
    }

    private var choicesEliminated: Array<Int> = new Array();

    private function collectChoicesToDisplay(chosen: Bool = false): Array<Choice> {
        var choices = new Array();
        for (choice in collectRawChoices()) {
            // check the choice's condition flag. Skip choices whose flag is not truthy.
            if (checkChoiceCondition(choice)) {
                // Check that the choice hasn't been chosen before if it is a one-time-only
                if (choicesEliminated.indexOf(choice.id) == -1) {
                    // fill the choice's h expressions after removing the flag expression
                    choices.push(choiceToDisplay(choice, chosen));
                }
            }
        }
        return choices;
    }

    /**
    Skip script execution to the desired section
    **/
    public function gotoSection(section: String): StoryFrame {
        // debugTrace('going to section ${section}');
        // this should clear the current choice depth
        choiceDepth = 0;
        // Update this section's view count
        if (!interp.variables.exists(section)) {
            throw 'Tried to divert to undeclared section ${section}.';
        }
        interp.variables[section] += 1;
        for (line in 0...scriptLines.length) {
            if (scriptLines[line].type.equals(DeclareSection(section))) {
                gotoLine(line);
            }
        }
        // Step past the section declaration to the first line of the section
        stepLine();
        return processNextLine();
    }
}
