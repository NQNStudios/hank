package hank;

import haxe.ds.Option;
import hank.Choice;

class LineID {
    public var sourceFile: String;
    public var lineNumber: Int;

    public function new(file: String, line: Int) {
        sourceFile = file;
        lineNumber = line;
    }

    public function equals(rhs: LineID) {
        return sourceFile == rhs.sourceFile && lineNumber == rhs.lineNumber;
    }
    public function toString() {
        return '${sourceFile}:${lineNumber}';
    }
}

class HankLine {
    public var id: LineID;
    public var type: LineType;

    public function new(id: LineID, type: LineType) {
        this.id = id;
        this.type = type;
    }

    public function toString() {
        return '${id.toString()}: ${type}';
    }
}

enum LineType {
    IncludeFile(path: String);
    OutputText(text: String);
    DeclareChoice(choice: Choice);
    DeclareSection(name: String);
    DeclareSubsection(parent: String, name: String);
    Divert(target: String);
    Gather(label: Option<String>, depth: Int, restOfLine: LineType);
    HaxeLine(code: String);
    HaxeBlock(lines: Int, code: String);
    BlockComment(lines: Int);
    EOF(file: String);
    NoOp;
}

