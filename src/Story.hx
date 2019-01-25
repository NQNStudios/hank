package src;

import haxe.ds.Option;
import haxe.io.Bytes;

// TODO sys.io.File calls might not work on HTML5 targets
import sys.io.FileOutput;

import hscript.Parser;
import hscript.Interp;

import src.HankLines.HankLine;
import src.HankLines.LineID;
import src.HankLines.LineType;
import src.Alt.AltState;
import src.Alt.AltBehavior;

@:allow(tests.StoryTest)
@:allow(src.StoryTestCase)
class Story {
    private var lineCount: Int = 0;
    private var scriptLines: Array<HankLine> = new Array();
    private var currentLineIdx: Int = 0;
    private var lastLineID = null;
    private var directory: String = "";
    private var parser = new Parser();
    private var interp = new Interp();
    private var transcriptFile: Option<FileOutput> = None;

    private var random: Random;

    private var embeddedHankBlocks: Map<LineID, Array<Bool>> = new Map();
    private var choiceDepth = 0;
    private var debugPrints: Bool;
    // Count how many choices have been parsed so each one can have a unique ID
    private var choicesParsed = 0;

    private function dummyLine(): HankLine {
        return {
            id: new LineID("", 0),
            type: NoOp
        };
    }

    private function currentLine() {
        // trace('getting line ${currentLineIdx} of ${scriptLines.length}');
        return scriptLines[currentLineIdx];
    }

    private function currentLineID() {
        return currentLine().id;
    }
    private function currentFile() {
        return currentLine().id.sourceFile;
    }

    private function debugTrace(v: Dynamic, ?infos: haxe.PosInfos) {
        if (debugPrints) {
            trace(v, infos);
        }
    }

    private function closeTranscript() {
        switch (transcriptFile) {
            case Some(file):
                file.close();
                // trace('saving out transcript');
            default:
        }
    }

    private function pushScriptLine(line: HankLine) {
        // trace('pushing ${line}');
        scriptLines.push(line);
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
            case Empty:
        }
    }

    private function logToTranscript(line: String) {
        switch (transcriptFile) {
            case Some(file):
                file.write(Bytes.ofString(line + "\n"));
            default:
                // debugTrace("No transcript file ");
        }
    }

    /**
    Create a new Story processor.
    @param randomSeed A seed for the random number generator used for shuffles, etc.
    @param debug Whether to output debug information to stdout
    @param transcriptPath an optional filepath to output a transcript of the story playthrough
    **/
    public function new(?randomSeed: Int, debug: Bool = false, transcriptPath="", debugPrints: Bool = false) {
        random = new Random(randomSeed);
        this.debugPrints = debugPrints;
        interp.variables['DEBUG'] = debug;
        if (transcriptPath.length > 0) {
            transcriptFile = Some(sys.io.File.write(transcriptPath));
        }
        logToTranscript('@${random.currentSeed}');
        interp.variables['story'] = this;
        interp.variables['random'] = random;

        // This piece of meta fuckery allows us to pass variable references in embedded script:
        interp.variables['variables'] = interp.variables;
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

        parseScriptFile(storyFile);
    }

    private function isEmbedded(line: HankLine) {
        return StringTools.startsWith(line.id.sourceFile, "EMBEDDED");
    }
    private function currentlyEmbedded(): Bool {
        return isEmbedded(currentLine());
    }

    private var sectionParsing = '';
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



                switch (equals_signs) {
                    // Stitches declared like = stitch
                    case 1:
                        // if it's a stitch, prefix the count variable with section name (this will be tough because the . operator is already defined and we want the main section to be an int view count, not a dictionary of its stiches)
                        interp.variables['${sectionParsing}__${sectionName}'] = 0;
                        // trace('${sectionParsing}__${sectionName}');
                        return DeclareSubsection(sectionParsing, sectionName);
                    // Technically, ======= also works for declaring a section
                    default:
                        sectionParsing = sectionName;
                        // Initialize its view count variable to 0
                        interp.variables[sectionName] = 0;
                        return DeclareSection(sectionName);
                }
            }
            
            else if (StringTools.startsWith(trimmedLine, "->")) {
                return Divert(StringTools.trim(trimmedLine.substr(2)));
            }
            
            else if (StringTools.startsWith(trimmedLine, "*") || StringTools.startsWith(trimmedLine, "+")) {
                var startingSymbol = trimmedLine.charAt(0);
                var expires = startingSymbol == '*';
                // For deep choices, spaces between choice symbols are acceptable, i.e. * * as seen in The Intercept source
                var depth = 0;
                var index = 0;
                var c = ' ';
                do {
                    c = trimmedLine.charAt(index);
                    if (c == startingSymbol) {
                        depth++;
                    }
                    index++;
                } while (c == startingSymbol || c == ' ');

                // Check for a label in parens
                var remainder = StringTools.trim(trimmedLine.substr(index-1));
                var label = None;
                var labelText = Util.findEnclosureIfStartsWith(remainder, '(', ')');
                if (labelText.length > 0) {
                    label = Some(labelText);
                    // Set the choice's label variable to 0
                    interp.variables[labelText] = 0;
                }

                var choiceText = StringTools.trim(StringTools.replace(remainder, '(${labelText})', ""));

                // Parse divert targets on the same line as the choice declaration
                var divertTarget: Option<String> = None;
                var divertIndex = choiceText.indexOf('->');
                if (divertIndex != -1) {
                    divertTarget = Some(StringTools.trim(choiceText.substr(divertIndex+2)));
                    choiceText = StringTools.trim(choiceText.substr(0, divertIndex));
                }

                return DeclareChoice({
                    label: label,
                    expires: expires,
                    text: choiceText,
                    depth: depth,
                    id: choicesParsed++,
                    divertTarget: divertTarget
                    });
            }
            
            else if (StringTools.startsWith(trimmedLine,"-")) {
                var gatherDepth = 1;
                while (trimmedLine.charAt(gatherDepth) == trimmedLine.charAt(gatherDepth-1)) {
                    gatherDepth += 1;
                }

                var remainder = StringTools.trim(trimmedLine.substr(gatherDepth));

                var label = None;
                var labelText = Util.findEnclosureIfStartsWith(remainder, '(', ')');
                if (labelText.length > 0) {
                    label = Some(labelText);
                    // Initialize the labeled gather's view count variable to 0
                    interp.variables[labelText] = 0;

                    // Don't add the label to the text
                    remainder = remainder.substr(labelText.length+2);
                }

                // Gathers store the parsed version of the next line.
                return Gather(label, gatherDepth, parseLine(remainder, rest));
            }
            
            else if (StringTools.startsWith(trimmedLine, "~")) {
                return HaxeLine(StringTools.trim(trimmedLine.substr(1)));
            }
            
            else if (StringTools.startsWith(trimmedLine, "```")) {
                var block = "";
                var lines = 2;
                // Loop until the end of the code block, incrementing the line count every time
                while (!StringTools.startsWith(StringTools.trim(rest[0]),"```")) {
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
        }
        
        else {
            return NoOp;
        }
    }

    private function parseScriptFile(file: String) {
        var unparsedLines = sys.io.File.getContent(file).split('\n');
        parseScript(unparsedLines, file);
    }

    private function parseScript(unparsedLines: Array<String>, file: String) {
        lineCount += unparsedLines.length;

        // Pre-Parse every line in the given file
        var idx = 0;
        while (idx < unparsedLines.length) { 
 
            var parsedLine = {
                id: new LineID(file, idx+1),
                type: NoOp
            };
            var unparsedLine = unparsedLines[idx];
            parsedLine.type = parseLine(unparsedLine, unparsedLines.slice(idx+1));
            if (file.indexOf('EMBEDDED') == 0) {
                // debugTrace('adding embedded line ${Std.string(parsedLine)}');
            }
            pushScriptLine(parsedLine);

            // Normal lines are parsed alone, but Haxe blocks are parsed as a group, so
            // the index needs to update accordingly 
            switch (parsedLine.type) {
                case HaxeBlock(lines, _):
                    for (i in 0...lines-1) {
                        pushScriptLine(dummyLine());
                    }
                    idx += lines;
                case BlockComment(lines):
                    for (i in 0...lines-1) {
                        pushScriptLine(dummyLine());
                    }
                    idx += lines;
                default:
                    idx += 1;
            }
        }

        pushScriptLine({
            id: new LineID(file, idx),
            type: EOF(file)
        });
    }

    private var started = false;
    public function nextFrame(): StoryFrame {
        if (!started) {
            gotoFile(rootFile);
            started = true;
        }
        var frame: StoryFrame = null;

        do {
            if (finished) {
                logFrameToTranscript(Finished);
                // trace('done here');
                return Finished;
            }
            frame = processNextLine();
            logFrameToTranscript(frame);
        } while (frame == Empty);

        return frame;
    }

    // TODO this doesn't allow for multiple declaration (var a, b;) and other edge cases that must exist
    private function processHaxeBlock(lines: String) {
        trace('processing ${lines}');
        var startingId = currentLineID();
        interp.variables['__temp__'] = startingId;
        // debugTrace('ORIGINAL LINES: ${lines}');
        var preprocessedLines = "";
        var linesArray = lines.split('\n');

        // Associate this haxe block's embedded Hank blocks with the Haxe block
        var childNumber = 0;

        for (line in linesArray) {
            // In order to preserve the values of variables declared in embedded Haxe,
            // we need to predeclare them all as globals in this Story's interpreter.
            var trimmed = StringTools.ltrim(line);
            if (trimmed.length > 0) {
                if (StringTools.startsWith(trimmed, "var ")) {
                    var varName = trimmed.split(" ")[1];
                    interp.variables[varName] = null;
                    // Strip out the `var ` prefix before executing so the global value doesn't get overshadowed by a new declaration
                    trimmed = trimmed.substr(4); 
                    preprocessedLines += trimmed + "\n";
                }
                // Hank script can be embedded in Haxe using commas, much like quasiquoting in Lisp.
                else if (StringTools.startsWith(trimmed, ',') && trimmed.charAt(1) != ',') {
                    var hankLine = StringTools.trim(trimmed.substr(1));
                    // TODO escape any " that might be in hank text
                    parseEmbeddedLines(startingId, childNumber, hankLine);
                    preprocessedLines += 'story.processEmbeddedLines(__temp__, ${childNumber}, "${hankLine}");\n';
                    childNumber++;
                } else {
                    preprocessedLines += trimmed+'\n';
                }
            }
        }

        trace('lines after processing single lines: ${preprocessedLines}');

        // Handle blocks of embedded Hank script
        while (Util.containsEnclosure(preprocessedLines, ',,,', ',,,')) {
            var hankBlockAsHaxe = '';
            var hankLines = StringTools.trim(Util.findEnclosure(preprocessedLines, ',,,', ',,,'));

            // TODO escape any " that might be in hank text of $line
            parseEmbeddedLines(startingId, childNumber, hankLines);
            hankBlockAsHaxe += 'story.processEmbeddedLines(__temp__, ${childNumber}, "${hankLines}");\n';
            childNumber++;

            preprocessedLines = Util.replaceEnclosure(preprocessedLines, hankBlockAsHaxe, ',,,', ',,,');
            // debugTrace('Found enclosure')
        }

        if (linesArray.length > 1) {
            // trace('Parsing haxe block "${preprocessedLines}"');
        }

        executeHaxeBlock(preprocessedLines);

        // trace(startingId);
        // trace(currentLineId);
        if (startingId.equals(currentLineID())) {stepLine();}
    }

    private var diverting = false;

    private function gotoLine(line: Int) {
        if (diverting) {
            // If the line is a section or subsection declaration, increment that variable
            var lineType = scriptLines[line].type;
            switch (lineType) {
                case Gather(Some(label), _, _):
                    // Gathers don't have to increment their view count here, because processLine() will
                case DeclareSection(name):
                    interp.variables[name]++; 
                case DeclareSubsection(parent, name):
                    interp.variables[parent]++;
                    interp.variables['${parent}__${name}']++;
                default:
            }
            diverting = false;
        }

        if (line >= 0 && line <= scriptLines.length) {
            currentLineIdx = line;
        } else {
            throw 'Tried to go to out of range line ${line}';
        }

        if (line == scriptLines.length) {
            // Reached the end of the script
            finished = true;
            // trace('end of script ${rootFile}');
        }
    }

    private function gotoLineByID(id: LineID) {
        var idx = 0;
        while (idx < scriptLines.length) {
            var line = scriptLines[idx];
            if (line.id.equals(id)) {
                gotoLine(idx);
                // trace('Found the right line for id ${id.sourceFile}:${id.lineNumber}');
                return;
            }
            idx++;
        }
        throw 'Error! Didn\'t find the right line for id ${id.sourceFile}:${id.lineNumber}';
    }

    private function stepLine() {
        // debugTrace('stepLine called');
        if (!finished) {
            // debugTrace('Stepping to line ${Std.string(scriptLines[currentLineIdx+1])}');
            gotoLine(currentLineIdx+1);
        } else {
            throw "Tried to step past the end of a script";
        }
    }

    private function processNextLine(): StoryFrame {
        // trace('line ${currentLineIdx} of ${scriptLines.length} is ${scriptLines[currentLineIdx]}');
        var scriptLine = currentLine();
        var frame = processLine(scriptLine);

        switch (frame) {
            case Error(message):
                var fullMessage = 'Error at line ${scriptLine.id}: ${message}';
                if (debugPrints) {
                    throw fullMessage;
                } else {
                    // This is a breaking error in production code. Output it to a file
                    trace(fullMessage);
                    logToTranscript('# ' + fullMessage);

                    return Finished;
                }
            default:
                return frame;
        }
    }

    private var finished: Bool = false;

    private function gotoEOF() {
        var currentFile = currentLineID().sourceFile;
        for (i in 0...scriptLines.length) {
            if (scriptLines[i].type.equals(EOF(currentFile))) {
                gotoLine(i);
                break;
            }
        }
    }

    private function gotoFile(file: String) {
        for (i in 0...scriptLines.length) {
            if (scriptLines[i].id.sourceFile == file) {
                // debugTrace('Found line for ${file}: ${scriptLines[i]}');
                gotoLine(i);
                break;
            }
        }
    }

    private var includedFilesProcessed = new Array();
    private var embeddedEntryPoint: LineID = null;

    private function parseEmbeddedLines(parent: LineID, childNumber: Int, lines: String) {
        if (!embeddedHankBlocks.exists(parent)) {
            embeddedHankBlocks[parent] = new Array();
        }
        var dummyFile = 'EMBEDDED BLOCK ${childNumber}/${Std.string(parent)}';

        parseScript(lines.split('\n'), dummyFile);
        embeddedHankBlocks[parent].push(true);
    }

    private var embeddedBlocksQueued: Array<String> = new Array();

    private function queueEmbeddedBlock(dummyFile: String) {
        if (embeddedBlocksQueued.length == 0) {
            // trace('${dummyFile} got here first');
            gotoFile(dummyFile);
        }
        embeddedBlocksQueued.push(dummyFile);
    }

    /** Execute script blocks embedded within Haxe blocks **/
    private function processEmbeddedLines(parent: LineID, childNumber: Int, lines: String) {
        embeddedEntryPoint = parent;
        var dummyFile = 'EMBEDDED BLOCK ${childNumber}/${Std.string(parent)}';
        // debugTrace('processing ${dummyFile}');
        queueEmbeddedBlock(dummyFile);
    }

    /**
    Scan ahead to get the next text that will be output during story execution,
    stopping if a choice is found
    **/ 
    private function nextOutputText(): String {
        var idx = currentLineIdx;
        var frame = processNextLine();
        var val = '';
        switch (frame) {
            case HasText(text):
                val = text;
            case Empty:
                return nextOutputText();
            default:
                // TODO if it's something that interrupts execution (such as a choice point), return no text and rewind.
                currentLineIdx = idx;
        }
        return val;
    }

    /** Execute a parsed script statement **/
    private function processLine(line: HankLine): StoryFrame {
        lastLineID = line.id;
        if (line.type != NoOp) {
            // trace('Processing ${Std.string(line)}');
        }

        var file = line.id.sourceFile;
        var type = line.type;
        switch (type) {
            // Execute text lines by evaluating their {embedded expressions}
            case OutputText(text):
                stepLine();
                var textToOutput = fillBraceExpressions(text);
                // trace('text to output: ${textToOutput}');
                var ogTextToOutput = textToOutput;
                if (textToOutput.length > 0) {
                    // Process diverts inside of text
                    if (textToOutput.indexOf("->") != -1) {
                        var beforeDivert = textToOutput.split('->')[0];
                        var divertTarget = StringTools.trim(textToOutput.split('->')[1]).split(' ')[0];
                        if (divertTarget.indexOf('|') != -1 ) {
                            divertTarget = divertTarget.substr(0, divertTarget.indexOf('|'));
                        }

                        divert(divertTarget);
                        var peekValue = nextOutputText();
                        // trace('peek value: ${peekValue}');
                        textToOutput = beforeDivert + peekValue;
                    }
                    var returning = StoryFrame.HasText(StringTools.trim(textToOutput));
                    // trace('returning ${returning} for ${ogTextToOutput} from line ${currentLineID()}');
                    return returning;
                } else {
                    // A line of text might contain only a conditional value whose condition isn't met. In that case, don't return a frame
                    return Empty;
                }

            // Include statements do nothing, because included files' content is only displayed if diverted to.
            case IncludeFile(path):
                if (currentlyEmbedded()) {
                    return Error("Trust me, you'd rather not use a double-nested INCLUDE statement.");
                }
                if (includedFilesProcessed.indexOf(path) == -1) {
                    gotoFile(path);
                } else {
                    stepLine();
                }
                return Empty;

            // Execute diverts by following them immediately
            case Divert(target):
                // If the divert is inside an embedded block, we can forget how we got there
                embeddedEntryPoint = null;
                embeddedBlocksQueued = new Array();

                return divert(target);

            case EOF(file):
                if (currentlyEmbedded()) {
                    embeddedBlocksQueued.remove(embeddedBlocksQueued[0]);
                    if (embeddedBlocksQueued.length == 0) {
                        // trace("reached end of embedded blocks");
                        gotoLineByID(embeddedEntryPoint);
                        stepLine();
                        // trace('now at line ${currentLineIdx} of ${scriptLines.length}');
                        embeddedEntryPoint = null;
                    } else {
                        // trace('another block was queued');
                        var nextBlock = embeddedBlocksQueued[0];
                        gotoFile(nextBlock);
                    }
                    return Empty;
                } else if (file != rootFile && includedFilesProcessed.indexOf(file) == -1) {
                    includedFilesProcessed.push(file);
                    stepLine();
                    return Empty;
                } else {
                    return Finished;
                }

            // When a new section is declared control flow in the current file stops. If this is the root file, we're finished.
            case DeclareSection(_):
                if (currentlyEmbedded()) {
                    return Error("Trust me, you'd rather not use a double-nested section declaration.");
                }
                if (currentFile() == rootFile) {
                    return Finished;
                }
                else {
                    gotoEOF();
                    return Empty;
                }

            case DeclareSubsection(_):
                 if (currentlyEmbedded()) {
                    return Error("Trust me, you'd rather not use a double-nested section declaration.");
                }
                if (currentFile() == rootFile) {
                    return Finished;
                }
                else {
                    gotoEOF();
                    return Empty;
                }

            // Execute haxe lines with hscript
            case HaxeLine(code):
                if (currentlyEmbedded()) {
                    return Error("Trust me, you'd rather not use a triple-nested Haxe line");
                }
                processHaxeBlock(code);
                return Empty;
            case HaxeBlock(_, code):
                if (currentlyEmbedded()) {
                    return Error("Trust me, you'd rather not use a triple-nested Haxe block");
                }
                processHaxeBlock(code);
                // trace('done that');
                return Empty;

            // Execute choice declarations by collecting the set of choices and presenting valid ones to the player
            case DeclareChoice(choice):
                if (choice.depth > choiceDepth) {
                    choiceDepth = choice.depth;
                } else if (choice.depth < choiceDepth) {
                    // The lines following a choice have run out. Now we need to look for the following gather
                    return gotoNextGather();
                }
                
                var availableChoices = [for (choice in collectChoicesToDisplay()) choice.text];
                if (availableChoices.length > 0) {
                    return HasChoices(availableChoices);
                } 
                else {
                    var fallback = collectFallbackChoice();
                    if (fallback != null) {
                        return chooseFallbackChoice(fallback);
                    } else {
                        throw 'Ran out of available choices at ${currentLineMapKey()}.';
                    }
                }

            // Execute gathers by updating the choice depth and continuing from that point
            case Gather(label, depth, nextPartType):
                switch (label) {
                    case Some(label):
                        // TODO qualify these variable names by section in which they appear
                        interp.variables[label]++;
                    default:
                }
                // +1 is applied because it's legal to place gather unnecessary gathers of choiceDepth+1 (i.e. gather on the first line in a series of choice/gather segments.)
                if (choiceDepth + 1 >= depth) {
                    choiceDepth = Math.floor(Math.min(choiceDepth, depth));
                    return processLine({
                        id: currentLineID(),
                        type: nextPartType
                    });
                } else {
                    return Error('Encountered a gather for depth ${depth} when the current depth was ${choiceDepth}');
                }

            // Skip comments and empty lines
            default:
                stepLine();
                return Empty;
        }
    }

    function currentLineMapKey() {
        return currentLineID().toString();
    }

    var behaviorMap = [
        ['sequence:'] => Sequence,
        ['!', 'once:'] => OnceOnly,
        ['&', 'cycle:'] => Cycle,
        ['~', 'shuffle:'] => Shuffle
    ];

    function evaluateAlternativeExpression(content: String): String {
        // If this alt expression hasn't been encountered before, Initialize its state and store it in the altstate map
        if (!altStates.exists(currentLineMapKey())) {
            altStates[currentLineMapKey()] = new Array();
            // trace('making new altstate array for ${currentLineMapKey()}');
        }
        if (altStates[currentLineMapKey()].length -1 < altExpressionIdx) {
            // trace('making new altstate for ${currentLineMapKey()} ${altExpressionIdx}');
            var behavior = Sequence;

            for (keyValuePair in behaviorMap.keyValueIterator()) {
                if (Util.startsWithOneOf(content, keyValuePair.key)) {
                    behavior = keyValuePair.value;
                    content = Util.stripPrefixes(content, keyValuePair.key);
                }
            }
            var alts = content.split('|');
            altStates[currentLineMapKey()].push(new AltState(behavior, alts, random));
        }

        //trace('evaluating expression ${currentLineMapKey()} ${altExpressionIdx} for ${content}');
        content = altStates[currentLineMapKey()][altExpressionIdx].next();
        trace (content);

        altExpressionIdx++;
        return content;
    }

    function isAlternativeExpression(content: String): Bool {
        for (altCodes in behaviorMap.keys()) {
            if (Util.startsWithOneOf(content, altCodes)) {
                return true;
            }
        }
        return content.indexOf('|') != -1;
    }

    var altStates: Map<String, Array<AltState>> = new Map();
    var altExpressionIdx = 0;
    /**
    Parse and evaluate brace expressions in the text. (Ink-style alternatives AND normal haxe expressions)
    **/
    function fillBraceExpressions(text: String) {
        // Track which alt expressions have been processed on each line
        altExpressionIdx = 0;
        var startingText = text;

        while (Util.containsEnclosure(text, "{", "}")) {
            var expression = Util.findEnclosure(text,"{","}");
            // debugTrace(expression);

            var value = '';

            if (isAlternativeExpression(expression)) {
                value = evaluateAlternativeExpression(expression);
            } else {
                value = evaluateHaxeExpression(expression);
            }

            // If an expression evaluates null, don't add any text.
            var stringValue = if (value != null) {
                Std.string(value);
            } else {
                "";
            }
            // trace (stringValue);

            text = Util.replaceEnclosure(text, stringValue, "{", "}");
        }

        // Also trim out all duplicate whitespace
        while (text.indexOf('  ') != -1) {
            text = StringTools.replace(text, '  ', ' ');
        }

        // trace ('final text for ${startingText} is ${text}');
        return StringTools.trim(text);
    }

    /**
    Make a choice for the player.
    @param index A valid index of the choice list returned by nextFrame()
    @return the choice output.
    **/
    public function choose(index: Int): String {
        var validChoices = collectChoicesToDisplay(true);
        var choiceTaken = validChoices[index];

        // When the user chooses a labeled choice, its flag should be incremented
        switch (choiceTaken.label) {
            case Some(labelText):
                interp.variables[labelText] += 1;
            default:
        }

        choiceDepth = choiceTaken.depth + 1;
        // Mark * choices as expired once chosen
        if (choiceTaken.expires) {
            // debugTrace('Chose "${choiceTaken.text}". Choice is now expiring ');
            choicesEliminated.push(choiceTaken.id);
        }

        switch (choiceTaken.divertTarget) {
            // If the choice declares a divert on the same line, follow that
            case Some(target):
                divert(target);
            case None:
                // Otherwise, follow the choice's branch.
                gotoChoiceBranch(choiceTaken);
        }
        
        // Log the choice's index to the transcript
        logToTranscript('>>> ${index}');
        logToTranscript(choiceTaken.text);
        return choiceTaken.text;
    }

    private function gotoChoiceBranch(choiceTaken: Choice) {
        // find the line where the choice taken occurs
        for (i in currentLineIdx...scriptLines.length) {
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
    }

    /**
    Search for the next gather that applies to the current choice depth, and follow it.
    @return If a suitable gather is found, Empty. Otherwise, an Error frame.
    **/
    function gotoNextGather(): StoryFrame {
        // debugTrace("called gotoNextGather()");
        var l = currentLineIdx+1;
        var file = currentFile();
        while (l < scriptLines.length && scriptLines[l].id.sourceFile == file) {
            // debugTrace('checking ${Std.string(scriptLines[l])} for gather');
            switch (scriptLines[l].type) {
                case DeclareSection(_):
                    return Error("Failed to find a gather or divert before the file ended.");
                case Gather(label, depth, type):
                    // TODO does this need to check depth?
                    switch (label) {
                        case None:
                        case Some(labelText):
                            interp.variables[labelText] += 1;
                    }
                    gotoLine(l);
                    return Empty;
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
        var file = currentFile();
        var nextLineFile = file;
        var l = currentLineIdx;
        while (l < scriptLines.length) {

            var type = scriptLines[l].type;
            switch (type) {
                // Collect choices of the current depth
                case DeclareChoice(choice):
                    // trace(Std.string(choice));
                    // Make a copy of the choice -- although I don't remember why
                    if (choice.depth == choiceDepth) {
                        choices.push({
                            expires: choice.expires,
                            label: choice.label,
                            id: choice.id,
                            depth: choice.depth,
                            text: choice.text,
                            divertTarget: choice.divertTarget
                            });
                    }
                // Stop searching when we hit a gather of the current depth
                case Gather(_, depth,_):
                    if (depth == choiceDepth){
                        break;
                    }
                // Or when we hit a section declaration
                case DeclareSection(_):
                    break;
                // Or when we hit EOF
                case EOF(_):
                    break;
                default:
            }

            nextLineFile = scriptLines[l++].id.sourceFile;
            // debugTrace(nextLineFile);
        }

        if (l < scriptLines.length) {
            // debugTrace('Stopped collecting choices before ${scriptLines[l].type}');
        } else {
            // debugTrace('Stopped collecting choices at EOF');
        }

        return choices;
    }

    private function collectFallbackChoice() {
        var choices = collectRawChoices();
        for (choice in choices) {
            if (choice.text.length == 0) {
                return choice;
            }
        }

        return null;
    }

    /**
    Return the first frame following a fallback choice, pushing the flow forward down that branch.
    **/
    private function chooseFallbackChoice(choice: Choice): StoryFrame {
        switch (choice.divertTarget) {
            case Some(target):
                // "choice then arrow syntax" should simply evaluate the lines following this choice
                if (target.length == 0) {
                    gotoChoiceBranch(choice);
                    return nextFrame();
                } else {
                    return divert(target);
                }
            default:
                throw 'Syntax error in fallback choice: no ->';
        }
    }

    /**
    Check if a choice's display condition is satisfied
    **/
    private function checkChoiceCondition(choice: Choice): Bool {
        return if (Util.startsWithEnclosure(choice.text, "{", "}")) {
            var conditionExpression = Util.findEnclosure(choice.text, "{", "}");
            var conditionValue = evaluateHaxeExpression(conditionExpression);
            conditionValue;
        } else true;
    }

    private function evaluateHaxeExpression(expression: String): Dynamic {
        // TODO It's common to want to && or || section/label names, but they're integers, not bools. Allow this.
        var expandedExpression = expression;

        try {
            var parsed = parser.parseString(expandedExpression);
            var value = interp.expr(parsed);
            // trace('evaluated ${expression} as ${value}');
            return value;
        } catch (e: Dynamic) {
            throw 'Error evaluating expression ${expression}: ${Std.string(e)}';
        }
    }

    private function executeHaxeBlock(block: String) {
        try {
            var program = parser.parseString(block);
            interp.execute(program);
        } catch (e: Dynamic) {
            throw 'Error evaluating haxe block: ${Std.string(e)}\n${block}';
        }
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

        choice.text = fillBraceExpressions(choice.text);
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
                    var displayChoice = choiceToDisplay(choice, chosen);
                    // Don't display fallback choices (choices with no text)
                    if (StringTools.trim(displayChoice.text.split('->')[0]).length > 0) {
                        choices.push(displayChoice);
                    }
                } else {
                    // debugTrace('can\'t display "${choice.text}" because it has expired.');
                }
            }
        }
        return choices;
    }

    private function currentSection(): Option<String> {
        for (line in scriptLines) {
            switch (line.type) {
                case DeclareSection(name):
                    if (linesInSection(name).indexOf(scriptLines[currentLineIdx]) != -1) {
                        return Some(name);
                    }
                default:
            }
        }

        return None;
    }

    private function linesInSection(section: String): Array<HankLine> {
        var lines = new Array();
        for (i in 0...scriptLines.length) {
            // trace('${scriptLines[i].type} vs ${DeclareSection(section)}');
            if (scriptLines[i].type.equals(DeclareSection(section))) {
                for (j in i+1...scriptLines.length) {
                    var line = scriptLines[j];
                    switch (line.type) {
                        case DeclareSection(_):
                            break;
                        case EOF(_):
                            break;
                        case NoOp:
                            // Don't add noOp lines to list, for purposes of finding if a subsection is the first thing in the section
                        default:
                            lines.push(line);
                    }
                }
                break;
            }
        }

        return lines;
    }

    private function subsectionsAndLabeledGathers(section: String): Map<String, HankLine> {
        var sectionLines = linesInSection(section);
        var subsections = new Map();
        for (line in sectionLines) {
            switch (line.type) {
                case DeclareSubsection(_, subName):
                    subsections[subName] = line;
                case Gather(Some(gatherName), _, _):
                    subsections[gatherName] = line;
                default:
            }
        }
        return subsections;
    }

    private function currentSubsectionsAndLabeledGathers(): Map<String, HankLine> {
        switch (currentSection()) {
            case None:
                return new Map();
            case Some(name):
                return subsectionsAndLabeledGathers(name);
        }
    }

    private function stepLineInDivert() {
        switch (scriptLines[currentLineIdx].type) {
            case DeclareSection(_):
            case DeclareSubsection(_, _):
            case NoOp:
            default: return;
        }
        stepLine();
    }

    /**
    Skip script execution to the desired target
    **/
    public function divert(target: String): StoryFrame {
        // trace('diverting to ${target}');
        // This is for tracking view counts
        diverting = true;

        // First check the current section for a subsection by the name of target
        if (currentSection() != None) {
            var currentTargets = currentSubsectionsAndLabeledGathers();

            if (currentTargets.exists(target)) {
                var lineToGo = currentTargets[target];
                // trace('HERE ${lineToGo}');
                var lineID = lineToGo.id;
                switch (lineToGo.type) {
                    case Gather(Some(t), depth, _):
                        // Diverting to a gather should adopt its choice depth
                        choiceDepth = depth;
                    // Sections and subsections
                    default:
                        // Diverting to a section should clear the current choice depth
                        choiceDepth = 0;
                }
                gotoLineByID(lineID);
                stepLineInDivert();

                return Empty;
            }
        }
        // debugTrace('going to section ${section}');
        // Update this section's view count
        // TODO or else parse __ notation for subsections
        if (!interp.variables.exists(target)) {
            throw 'Tried to divert to undeclared section/label ${target}.';
        }

        // Subsections can be diverted to globally by using 2 underscores (__) instead of Ink's dot (.) notation
        var parts = target.split('__');

        if (parts.length == 1) {
            for (line in 0...scriptLines.length) {
                var type = scriptLines[line].type;
                if (type.equals(DeclareSection(target))) {
                    // Diverting to a section should clear the current choice depth
                    choiceDepth = 0;

                    // If a section has no top-level content but starts with a subsection, divert there
                    var sectionLines = linesInSection(target);
                    if (sectionLines.length == 0) {
                        throw 'Do not have an empty section, ${target}!';
                    }
                    switch (sectionLines[0].type) {
                        case DeclareSubsection(_):
                            gotoLineByID(sectionLines[0].id);

                        // Go to the start of the section if it has top-level content
                        default:
                            gotoLine(line);
                    }

                }
                else {
                    switch (type) {
                        case Gather(Some(t), depth, _):
                            if (t == target) {
                                // Diverting to a gather should adopt its choice depth
                                choiceDepth = depth;
                                gotoLine(line);
                            }
                        default:
                    }

                }
            }
            // Step past the section declaration to the first line of the section
            stepLineInDivert();
        }
        else if (parts.length == 2) {
            var subTargets = subsectionsAndLabeledGathers(parts[0]);
            var lineToGo = subTargets[parts[1]];
            gotoLineByID(lineToGo.id);
            stepLineInDivert();
        }
        else {
            throw "Can't have stitches within stitches";
        }
        return Empty;
    }
}

// TODO inject functions to the embedded scope that let you boolcheck if a flag has been seen (accounting for current section scope)