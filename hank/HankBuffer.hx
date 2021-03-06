package hank;

using StringTools;

import haxe.ds.Option;

typedef PreloadedFiles = Map<String, String>;

/**
	A position in a HankBuffer, used for debugging.
**/
class Position {
	public var file:String;
	public var line:Int;
	public var column:Int;

	public function new(file:String, line:Int, column:Int) {
		this.file = file;
		this.line = line;
		this.column = column;
	}

	public function equals(other:Position) {
		return file == other.file && line == other.line && column == other.column;
	}
}

/**
	Reference to a slice of the buffer, which expires when the buffer changes its state.
**/
@:allow(hank.HankBuffer)
class BufferSlice {
	public var start(default, null):Int;
	public var length(default, null):Int;

	var anchorPosition:Position;
	var buffer:HankBuffer;

	private function new(start:Int, length:Int, buffer:HankBuffer) {
		this.start = start;
		this.length = length;
		this.anchorPosition = buffer.position();
		this.buffer = buffer;
	}

	public function checkValue():String {
		if (!buffer.position().equals(anchorPosition)) {
			throw 'Tried to access an expired BufferSlice.';
		}
		return buffer.peekAhead(start, length);
	}
}

typedef BufferOutput = {
	output:String,
	terminator:String
};

/**
	Helper class for reading/parsing information from a string buffer. Completely drops comments
**/
@:allow(tests.HankBufferTest)
class HankBuffer {
	var path:String;
	var cleanBuffer:String;
	var rawBuffer:String;
	var line:Int;
	var column:Int;

	public function new(path:String, rawBuffer:String, line:Int = 1, column:Int = 1) {
		if (rawBuffer == null) {
			throw 'Tried to create buffer of path $path with null contents: $rawBuffer';
		}

		this.path = path;
		this.rawBuffer = rawBuffer;
		// Keep a clean buffer for returning data without comments getting in the way
		this.cleanBuffer = stripComments(rawBuffer, '//', '\n', false);
		this.cleanBuffer = stripComments(cleanBuffer, '/*', '*/', true);
		this.line = line;
		this.column = column;
	}

	// TODO because this obfuscates the position of parsing, maybe it should be deprecated
	public static function Dummy(text:String) {
		return new HankBuffer('_', text, 1, 1);
	}

	public static function FromFile(path:String, ?files:PreloadedFiles) {
		// Keep a raw buffer of the file for tracking accurate file positions
		#if sys
		var rawBuffer = sys.io.File.getContent(path);
		#else
		if (files == null) {
			throw 'Tried to open file $path on a non-sys platform without passing in preloaded files';
		} else if (!files.exists(path)) {
			throw 'Tried to open file $path that was not pre-loaded';
		}
		var rawBuffer = files[path];
		#end
		return new HankBuffer(path, rawBuffer);
	}

	public function lines():Array<String> {
		var lines = cleanBuffer.split('\n');
		drop(cleanBuffer);
		return lines;
	}

	function stripComments(s:String, o:String, c:String, dc:Bool):String {
		while (s.indexOf(o) != -1) {
			var start = s.indexOf(o);
			var end = s.indexOf(c, start);
			if (end == -1) {
				s = s.substr(0, start);
			} else {
				if (dc)
					end += c.length;
				s = s.substr(0, start) + s.substr(end);
			}
		}
		return s;
	}

	public function indexOf(s:String, start:Int = 0):Int {
		return cleanBuffer.indexOf(s, start);
	}

	public function everyIndexOf(s:String):Array<Int> {
		return [for (i in 0...cleanBuffer.length) i].filter(function(i) return cleanBuffer.charAt(i) == s);
	}

	public function everyRootIndexOf(s:String) {
		return [for (i in everyIndexOf(s)) i].filter(function(i) return depthAtIndex('{', '}', i) == 0);
	}

	public function rootIndexOf(s:String) {
		// The DRYest possible implementation causes the program to hang when files are big:
		// return everyRootIndexOf(s)[0];

		var start = 0;
		while (true) {
			start = indexOf(s, start);
			if (start == -1)
				return -1;
			if (depthAtIndex('{', '}', start) == 0) {
				return start;
			}
			start += 1;
		}
	}

	public function rootSplit(delimiter:String):Array<String> {
		var rootIndices = everyRootIndexOf(delimiter);

		if (rootIndices.length == 0) {
			return [cleanBuffer];
		}

		var substrs = [];
		var lastIdx = 0;
		for (i in rootIndices) {
			substrs.push(cleanBuffer.substr(lastIdx, i - lastIdx));
			lastIdx = i + 1;
		}
		substrs.push(cleanBuffer.substr(lastIdx));
		return substrs;
	}

	public function length():Int {
		return cleanBuffer.length;
	}

	public function position():Position {
		return new Position(path, line, column);
	}

	/** Peek at contents buffer waiting further ahead in the buffer **/
	public function peekAhead(start:Int, length:Int):String {
		return cleanBuffer.substr(start, length);
	}

	/** Peek through the buffer until encountering one of the given terminator sequences
		@param eofTerminates Whether the end of the file is also a valid terminator
	**/
	public function peekUntil(terminators:Array<String>, eofTerminates:Bool = false, raw:Bool = false):Option<BufferOutput> {
		var buffer = raw ? rawBuffer : cleanBuffer;
		if (buffer.length == 0)
			return None;

		var index = buffer.length;

		var whichTerminator = '';
		for (terminator in terminators) {
			var nextIndex = buffer.indexOf(terminator);
			if (nextIndex != -1 && nextIndex < index) {
				index = nextIndex;
				whichTerminator = terminator;
			}
		}

		return if (index < buffer.length || eofTerminates) {
			Some({
				output: buffer.substr(0, index),
				terminator: whichTerminator
			});
		} else {
			None;
		}
	}

	/**
		Drop the given string from the front of the raw buffer, updating the current position according to the raw buffer
	**/
	function dropRaw(s:String) {
		var actual = rawBuffer.substr(0, s.length);
		if (actual != s) {
			throw 'Expected to drop "${s}" but was "${actual}"';
		}

		var lines = s.split('\n');
		if (lines.length > 1) {
			line += lines.length - 1;
			column = lines[lines.length - 1].length + 1;
		} else {
			column += lines[0].length;
		}

		rawBuffer = rawBuffer.substr(s.length);
	}

	/** Drop text directly from the clean buffer **/
	function dropClean(s:String) {
		var actual = cleanBuffer.substr(0, s.length);

		if (actual != s) {
			throw 'Expected to drop "${s}" but was "${actual}"';
		}

		cleanBuffer = cleanBuffer.substr(s.length);
	}

	/**
		Drop the given string from the front of the unified buffer object, keeping the two back-end buffers synchronized
	**/
	public function drop(s:String) {
		var untilNextComment = peekUntil(['//', '/*'], false, true);

		switch (untilNextComment) {
			case Some({output: rawS, terminator: commentOpener}) if (rawS.length < s.length):
				var commentTerminator = switch (commentOpener) {
					case '//': '\n';
					case '/*': '*/';
					default: throw 'FUBAR';
				}
				dropRaw(rawS + commentOpener);
				dropClean(rawS);
				var untilEndOfComment = peekUntil([commentTerminator], true, true);
				switch (untilEndOfComment) {
					case Some({output: comment, terminator: _}):
						dropRaw(comment);
						if (commentTerminator != '\n') {
							dropRaw(commentTerminator);
						}
						// Drop the rest of the clean sequence
						var rest = s.substr(rawS.length);

						drop(rest);
					default: throw 'FUBAR';
				}
			default:
				dropClean(s);
				dropRaw(s);
		}
	}

	/** Take data from the file until encountering one of the given terminator sequences. **/
	public function takeUntil(terminators:Array<String>, eofTerminates:Bool = false, dropTerminator = true):Option<BufferOutput> {
		return switch (peekUntil(terminators, eofTerminates)) {
			case Some({output: s, terminator: t}):
				// Remove the desired data from the buffer
				drop(s);

				// Remove the terminator that followed the data from the buffer
				if (dropTerminator) {
					drop(t);
				}

				// Return the desired data
				Some({output: s, terminator: t});
			case None:
				None;
		}
	}

	public function peek(chars:Int) {
		if (cleanBuffer.length < chars) {
			throw 'Not enough characters left in buffer.';
		}
		var data = cleanBuffer.substr(0, chars);
		return data;
	}

	public function take(chars:Int) {
		var data = peek(chars);
		drop(data);
		return data;
	}

	/** Count consecutive occurrence of the given string at the current buffer position, dropping the counted sequence **/
	public function countConsecutive(s:String) {
		var num = 0;

		while (cleanBuffer.substr(0, s.length) == s) {
			num += 1;
			drop(s);
		}

		return num;
	}

	/** If the given expression comes next in the buffer, take its contents. Otherwise, return None **/
	public function expressionIfNext(o:String, c:String):Option<String> {
		if (cleanBuffer.startsWith(o) && cleanBuffer.indexOf(c) != -1) {
			drop(o);
			var end = cleanBuffer.indexOf(c);
			var content = take(end);
			drop(c);
			return Some(content);
		}
		return None;
	}

	/** DRY Helper for peekLine() and takeLine() **/
	function getLine(trimmed:String, retriever:Array<String>->Bool->Bool->Option<BufferOutput>, dropNewline:Bool):Option<String> {
		var nextLine = retriever(['\n'], true, false);
		return switch (nextLine) {
			case Some({output: nextLine, terminator: _}):
				if (dropNewline && !isEmpty()) {
					drop('\n');
				}
				if (trimmed.indexOf('r') != -1) {
					nextLine = nextLine.rtrim();
				}
				if (trimmed.indexOf('l') != -1) {
					nextLine = nextLine.ltrim();
				}
				Some(nextLine);
			case None:
				None;
		};
	}

	/** Peek the next line of data from the file.
		@param trimmed Which sides of the line to trim ('r' 'l', 'lr', or 'rl')
	**/
	public function peekLine(trimmed = ''):Option<String> {
		return getLine(trimmed, peekUntil, false);
	}

	/** Take the next line of data from the file.
		@param trimmed Which sides of the line to trim ('r' 'l', 'lr', or 'rl')
	**/
	public function takeLine(trimmed = ''):Option<String> {
		return getLine(trimmed, takeUntil, true);
	}

	public function skipWhitespace(terminator:String = '') {
		var nextTerm = cleanBuffer.indexOf(terminator);
		var withoutTerm = cleanBuffer.length - cleanBuffer.ltrim().length;
		var end = if (nextTerm <= 0) withoutTerm else Math.floor(Math.min(nextTerm, withoutTerm));
		var whitespace = cleanBuffer.substr(0, end);
		drop(whitespace);
	}

	public function isEmpty() {
		return cleanBuffer.length == 0;
	}

	/** 
		By counting matched pairs of o and c, find out the nesting depth of the char at the given index
	**/
	public function depthAtIndex(o:String, c:String, index:Int) {
		var depth = 0;
		var snippet = cleanBuffer.substr(0, index);
		for (i in 0...snippet.length) {
			var whichC = snippet.charAt(i);
			if (whichC == o) {
				depth += 1;
			} else if (whichC == c) {
				depth -= 1;
			}
		}
		return depth;
	}

	/** Return the start index and length of number of characters left the buffer before a nestable expression terminates **/
	public function findNestedExpression(o:String, c:String, start:Int = 0, throwExceptions:Bool = true):Option<BufferSlice> {
		var startIdx = start;
		var endIdx = start;
		var depth = 0;

		var nextIdx = start;
		do {
			var nextOpeningIdx = cleanBuffer.indexOf(o, nextIdx);
			var nextClosingIdx = cleanBuffer.indexOf(c, nextIdx);

			if (nextOpeningIdx == -1 && nextClosingIdx == -1) {
				return None;
			} else if (depth == 0 && nextOpeningIdx == -1) {
				if (throwExceptions)
					throw 'Your input file $path has an expression with an unmatched closing operator $c';
				else
					return None;
			} else if (depth != 0 && nextClosingIdx == -1) {
				if (throwExceptions)
					throw 'Your input file $path has an expression with an unmatched opening operator $o';
				else
					return None;
			} else if (nextOpeningIdx != -1 && nextOpeningIdx < nextClosingIdx) {
				if (depth == 0) {
					startIdx = nextOpeningIdx;
				}
				depth += 1;
				nextIdx = nextOpeningIdx + o.length;
			} else {
				depth -= 1;
				nextIdx = nextClosingIdx + c.length;
				endIdx = nextClosingIdx + c.length;
			}
		} while (depth > 0 && nextIdx < cleanBuffer.length);

		return Some(new BufferSlice(startIdx, endIdx - startIdx, this));
	}
}
