package hank;

using StringTools;

import haxe.ds.Option;

using Extensions.Extensions;

import hank.StoryTree;
import hank.Alt.AltInstance;

enum OutputType {
	Text(t:String); // Pure text that is always displayed
	AltExpression(a:Alt);
	HExpression(h:String); // A Haxe expression inside braces whose value will be inserted
	HCall(h:String); // An embedded Haxe expression preceded by ~. Will not be inserted
	InlineDivert(t:String); // A divert statement on the same line as an output sequence.
	ToggleOutput(o:Output,
		invert:Bool); // Output that will sometimes be displayed (i.e. [bracketed] section in a choice text or the section following the bracketed section)
}

@:allow(tests.ParserTest, hank.ChoiceExtension)
class Output {
	var parts:Array<OutputType> = [];
	var diverted:Bool = false;

	public function new(?parts:Array<OutputType>) {
		this.parts = if (parts != null) {
			parts;
		} else {
			[];
		};
	}

	public function isEmpty() {
		return parts.length == 0;
	}

	public static function parse(buffer:HankBuffer, isPartOfAlt:Bool = false):Output {
		var parts = [];

		// We can run into performance issues if we keep biting off from the entire buffer
		var eol = buffer.rootIndexOf('\n');
		if (eol == -1) {
			eol = buffer.length();
		}
		// trace('found eol @ $eol');
		buffer = HankBuffer.Dummy(buffer.take(eol));

		// If brackets appear on this line, the first step is to break it up into ToggleOutput segments because ToggleOutputs need to be outermost in the hierarchy.
		var findBracketExpression = buffer.findNestedExpression('[', ']');
		switch (findBracketExpression) {
			case Some(slice):
				if (slice.start < eol) {
					var part1 = buffer.take(slice.start);
					buffer.take(1);
					var part2 = buffer.take(slice.length - 2);
					buffer.take(1);

					var parts = parse(HankBuffer.Dummy(part1)).parts;
					parts.push(ToggleOutput(parse(HankBuffer.Dummy(part2)), false));
					parts.push(ToggleOutput(parse(buffer), true));
					return new Output(parts);
				}

			case None:
				// This is an individual Output to parse
		}

		while (!buffer.isEmpty()) {
			var endSegment = buffer.length();
			var findBraceExpression = buffer.findNestedExpression('{', '}');
			switch (findBraceExpression) {
				case Some(slice):
					endSegment = slice.start;
				default:
			}
			if (endSegment == buffer.length() || endSegment != 0) {
				var peekLine = buffer.peekLine().unwrap();
				if (peekLine.length < endSegment) {
					var text = buffer.takeLine().unwrap();
					if (text.length > 0) {
						if (text.ltrim().startsWith('~'))
							parts.push(HCall(text.ltrim().substr(1)));
						else
							parts.push(Text(text));
					}
					break;
				} else {
					var text = buffer.take(endSegment);
					// If text starts with ~, it's actually a silent HCall.
					if (text.ltrim().startsWith('~'))
						parts.push(HCall(text.ltrim().substr(1)));
					else
						parts.push(Text(text));
				}
			} else {
				parts.push(parseBraceExpression(buffer));
			}
		}

		parts = updateLastPart(parts, isPartOfAlt);
		// trace('parts in whole: $parts');
		return new Output(parts);
	}

	private static function updateLastPart(parts:Array<OutputType>, isPartOfAlt:Bool) {
		// If the last output is Text, it could contain optional text or an inline divert. Or just need rtrimming.
		if (parts.length > 0) {
			var lastPart = parts[parts.length - 1];
			switch (lastPart) {
				case Text(t):
					parts.pop(); // .remove() removes the FIRST occurance. Ha, that bug took forever to find!
					parts = parts.concat(parseLastText(t));
				default:
			}
		}
		return parts;
	}

	/** The last part of an output expression outside of braces can include an inline divert -> like_so **/
	public static function parseLastText(text:String):Array<OutputType> {
		var parts = [];

		var divertIndex = text.lastIndexOf('->');
		if (divertIndex != -1) {
			if (divertIndex != 0) {
				parts.push(Text(text.substr(0, divertIndex)));
			}
			var target = text.substr(divertIndex + 2).trim();
			parts.push(InlineDivert(target));
		} else {
			parts.push(Text(text));
		}

		return parts;
	}

	public static function parseBraceExpression(buffer:HankBuffer):OutputType {
		switch (Alt.parse(buffer)) {
			case Some(altExpression):
				return AltExpression(altExpression);
			default:
				return parseHaxeExpression(buffer);
		}
	}

	public static function parseHaxeExpression(buffer:HankBuffer):OutputType {
		var rawExpression = buffer.findNestedExpression('{', '}').unwrap().checkValue();
		// Strip out the enclosing braces
		var hExpression = rawExpression.substr(1, rawExpression.length - 2);

		// Evil bug starts here.
		var checkNext = buffer.take(rawExpression.length);

		return HExpression(hExpression);
	}

	/** If an instance of Output ends in an inline divert, remove that divert from this Output and return its target **/
	public function takeInlineDivert():Option<String> {
		if (parts.length == 0)
			return None;
		var lastPart = parts[parts.length - 1];
		switch (lastPart) {
			case InlineDivert(target):
				parts.remove(lastPart);
				parts = updateLastPart(parts, false);
				return Some(target);
			default:
				return None;
		}
	}

	public function format(story:Story, hInterface:HInterface, random:Random, altInstances:Map<Alt, AltInstance>, scope:Array<StoryNode>,
			displayToggles:Bool):String {
		var fullOutput = '';

		diverted = false; // Clear the diverted flag

		// trace(parts);

		for (part in parts) {
			switch (part) {
				case Text(t):
					fullOutput += t;
				case AltExpression(a):
					// If this alt hasn't been evaluated yet, we need to make an instance for it
					if (!altInstances.exists(a)) {
						altInstances[a] = new AltInstance(a.behavior, a.outputs, random);
					}
					var nextBranchOutput = altInstances[a].next();
					fullOutput += nextBranchOutput.format(story, hInterface, random, altInstances, scope, displayToggles);
					if (nextBranchOutput.diverted) {
						break;
					}
				case HExpression(h):
					var value = story.formatForInsertion(hInterface.expr(h, scope));
					// HExpressions that start with ',' will be parsed and formatted as their own outputs
					// (If that sounds confusing, see examples/divert-line to clarify).
					if (value.startsWith(',')) {
						var nestedOutput = Output.parse(HankBuffer.Dummy(value.substr(1)));
						value = nestedOutput.format(story, hInterface, random, altInstances, scope, displayToggles);
						fullOutput += value;
						if (nestedOutput.diverted)
							break;
					} else {
						fullOutput += value;
					}
				case HCall(h):
					hInterface.runEmbeddedHaxe(h, scope);
				// Don't append anything
				case InlineDivert(t):
					// follow the divert. If the next expression is an output, concatenate the pieces together. Otherwise, terminate formatting
					story.divertTo(t);
					// Track whether the last call to format() resulted in a divert, so nested Outputs can interrupt the flow of their parents
					diverted = true;
					switch (story.nextFrame()) {
						case HasText(text):
							fullOutput += text;
						default:
					}
					break; // Don't format the rest of this Output's parts

				case ToggleOutput(o, b):
					if (b == displayToggles) {
						fullOutput += o.format(story, hInterface, random, altInstances, scope, displayToggles);
					}
			}
		}

		return fullOutput;
	}
}
