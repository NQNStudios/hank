package hank;

using Type;

import hank.HankBuffer;

using StringTools;

import haxe.ds.Option;

using hank.Extensions;
using HankAST.ASTExtension;

import hank.Choice;

using Choice.ChoiceExtension;

import hank.Choice.FallbackChoice;
import hank.HankAST.ExprType;
import hank.StoryTree;
import hank.Alt.AltInstance;

/**
	Possible states of the story being executed.
**/
enum StoryFrame {
	HasText(text:String);
	HasChoices(choices:Array<String>);
	Finished;
}

typedef InsertionHook = Dynamic->String;

enum EmbedMode {
	/**
		The current embedded Stories are to be executed sequentially until they return Finished
	 */
	Tunnel;

	/**
		The current embedded Stories are to be executed sequentially until they return HasChoices. Choices will be aggregated into a single frame
	 */
	Thread;
}

/**
	Runtime interpreter for Hank stories.
**/
@:allow(hank.StoryTestCase)
class Story {
	var hInterface:HInterface;

	public var insertionHooks:Map<String, InsertionHook>;

	var random:Random;

	var ast:HankAST;
	var exprIndex:Int;

	var storyTree:StoryNode;
	var viewCounts:Map<StoryNode, Int>;
	var nodeScopes:Array<StoryNode>;
	var altInstances:Map<Alt, AltInstance> = new Map();

	var parser:Parser;
	var embedMode:EmbedMode = Tunnel;
	var embeddedBlocks:Array<Story> = [];
	var parent:Option<Story> = None;

	var choicesTaken:Array<Int> = [];
	var weaveDepth = 0;

	var storedFrame:Option<StoryFrame> = None;

	function new(r:Random, p:Parser, ast:HankAST, st:StoryNode, sc:Array<StoryNode>, vc:Map<StoryNode, Int>, hi:HInterface) {
		this.insertionHooks = new Map();

		this.random = r;
		this.parser = p;
		this.ast = ast;
		this.storyTree = st;
		this.nodeScopes = sc;
		this.viewCounts = vc;
		this.hInterface = hi;
	}

	function currentFile() {
		return ast[0].position.file;
	}

	function embeddedStory(h:String):Story {
		var ast = parser.parseString(h);

		var embeddedHInterface = hInterface.clone();
		var story = new Story(random, // embedded stories must continue giving deterministic random numbers without resetting -- to avoid exploitable behavior

			parser, ast, // embedded stories have their OWN AST of Hank statements

			// but they keep the parent's view count tree and current scope
			storyTree,
			nodeScopes, viewCounts, embeddedHInterface);
		story.exprIndex = 0;
		story.parent = Some(this);
		return story;
	}

	function storyFork(t:String):Story {
		// Everything is the same as when embedding blocks, but a fork uses the same AST as its parent -- simply starting after a hypothetical divert
		var story = new Story(random, parser, this.ast, storyTree, nodeScopes, viewCounts, hInterface);
		// Just trust me that in Tunneling mode, the embedded stories don't need a parent. This is because I was too lazy to disambiguate tunnel mode from embedded mode.
		if (embedMode == Thread)
			story.parent = Some(this);
		// trace('story parent: ${story.parent.match(Some(_))}');
		story.divertTo(t);
		return story;
	}

	public static function FromAST(script:String, ast:HankAST, ?randomSeed:Int):Story {
		var random = new Random(randomSeed);
		var storyTree = StoryNode.FromAST(ast);
		var nodeScopes = [storyTree];
		var viewCounts = storyTree.createViewCounts();

		var hInterface = new HInterface(viewCounts);

		var story = new Story(random, new Parser(), ast, storyTree, nodeScopes, viewCounts, hInterface);
		hInterface.setStory(story);
		hInterface.addVariable('story', story);

		story.runRootIncludedHaxe(script);
		story.exprIndex = ast.findFile(script);
		return story;
	}

	public static function FromFile(script:String, ?files:PreloadedFiles, ?randomSeed:Int):Story {
		var parser = new Parser();
		var ast = parser.parseFile(script, files);
		return Story.FromAST(script, ast, randomSeed);
	}

	/* Go through each included file executing all Haxe embedded at root level */
	private function runRootIncludedHaxe(rootFile:String) {
		var i = 0;
		while (i < ast.findFile(rootFile)) {
			var file = ast[i].position.file;
			switch (ast[i].expr) {
				case EHaxeLine(h) | EHaxeBlock(h):
					hInterface.runEmbeddedHaxe(h, nodeScopes);
					i += 1;
				default:
					i = ast.findEOF(file) + 1;
			}
		}
		// TODO when parsing an included file, make sure the first line that isn't embedded haxe (block or line form) is a Knot
	}

	public function nextFrame():StoryFrame {
		switch (storedFrame) {
			case Some(f):
				storedFrame = None;
				return f;
			default:
		}

		// trace (embeddedBlocks.length);
		// trace (embedMode);
		while (embeddedBlocks.length > 0) {
			switch (embedMode) {
				case Tunnel:
					var nf = embeddedBlocks[0].nextFrame();
					if (nf == Finished) {
						embeddedBlocks.remove(embeddedBlocks[0]);
					} else {
						return nf;
					}
				case Thread:
					var idx = 0;
					while (idx < embeddedBlocks.length) {
						var nf = embeddedBlocks[idx].nextFrame();
						switch (nf) {
							case HasChoices(_) | Finished:
								// trace('Hit end of flow for thread $idx');
								idx++;
								// exprIndex++;
								continue;
							default:
								return nf;
						}
					}

					// All of the threaded blocks are out of content, so follow the original fork until it also runs out of flow.
					break;
			}
		}
		if (exprIndex >= ast.length) {
			if (embedMode == Thread) {
				// trace('Warning: Hit EOF while threading (are you sure you meant to do that?)');
				return nextChoiceFrame();
			}
			return Finished;
		}

		// trace('It fell to the roots next expr: ${ast[exprIndex].expr}');
		var rootNf = processExpr(ast[exprIndex].expr);

		// if (parent == None)	trace('root frame: $rootNf');

		if (embedMode == Thread) {
			if (rootNf == Finished) {
				return nextChoiceFrame();
			}
		}

		return rootNf;
	}

	private function processExpr(expr:ExprType):StoryFrame {
		switch (expr) {
			case EOutput(output):
				exprIndex += 1;
				var text = output.format(this, hInterface, random, altInstances, nodeScopes, false).trim();
				return finalTextProcessing(text);
			case EHaxeLine(h):
				exprIndex += 1;

				hInterface.runEmbeddedHaxe(h, nodeScopes);
				return nextFrame();
			case EHaxeBlock(h):
				exprIndex += 1;
				hInterface.runEmbeddedHaxe(h, nodeScopes);
				return nextFrame();
			// Fallback choices simply advance flow using divert syntax by not specifying a target
			case EDivert([""]):
				exprIndex += 1;

			// The most common form of divert is to one other location.
			case EDivert([oneTarget]):
				divertTo(oneTarget);

				return nextFrame();

			// Tunneling statements!
			case EDivert(targets):
				switch (targets.pop()) {
					case target if (target != ''):
						// If the last target isn't empty, we want to fork the main story to start at that point once the tunnels are done.
						// trace('this divert');
						divertTo(target);
					case '':
						exprIndex++;
					case null:
						throw 'No divert targets!';
				}

				// Spawn the rest of the forks in tunneling mode
				for (target in targets) {
					// trace('embedded $target');
					var fork = storyFork(target);
					// trace(fork != null);
					embeddedBlocks.push(fork);
					// trace(embeddedBlocks.length);
				}

				// trace(embeddedBlocks.length);

				return nextFrame();

			case EThread(target):
				// The thread only needs to be added once
				exprIndex++;
				embedMode = Thread;
				// trace('before: ${embeddedBlocks.length}');
				embeddedBlocks.push(storyFork(target));
				// trace('after: ${embeddedBlocks.length}');
				// ^ These before/after comments help diagnose whether divert() is erasing the embedded blocks before they can start
				// trace ('starting thread $target');
				var nf = nextFrame();
				// trace('frame immediately after: $nf');
				return nf;

			case EGather(label, depth, nextExpr):
				// gathers need to update their view counts
				switch (label) {
					case Some(l):
						var node = resolveNodeInScope(l)[0];
						viewCounts[node] += 1;
					case None:
				}
				weaveDepth = depth;
				return processExpr(nextExpr);

			case EChoice(choice):
				if (choice.depth > weaveDepth) {
					weaveDepth = choice.depth;
				} else if (choice.depth < weaveDepth) {
					gotoNextGather();
					return nextFrame();
				}

				return nextChoiceFrame();

			default:
				trace('$expr is not implemented');
				return Finished;
		}
		return Finished;
	}

	private function nextChoiceFrame() {
		var optionsText = [
			for (c in availableChoices())
				c.output.format(this, hInterface, random, altInstances, nodeScopes, false)
		];
		if (optionsText.length > 0) {
			return finalChoiceProcessing(optionsText);
		} else {
			var fallback = fallbackChoice();
			switch (fallback.choice.divertTarget) {
				case Some(t) if (t.length > 0):
					var fallbackText = evaluateChoice(fallback.choice);
					if (fallbackText.length > 0) {
						throw 'For some reason a fallback choice evaluated to text!';
					}
					return nextFrame();
				default:
					exprIndex = fallback.index + 1;
					weaveDepth = fallback.choice.depth + 1;
					return nextFrame();
			}
		}
	}

	private function traceChoiceArray(choices:Array<Choice>) {
		for (choice in choices) {
			trace(choice.toString());
		}
		trace('---');
	}

	private function availableChoices():Array<Choice> {
		var choices = [];

		// If we're threading, collect all the childrens' choices, too.
		if (embedMode == Thread) {
			var idx = 0;
			for (thread in embeddedBlocks) {
				choices = choices.concat(thread.availableChoices());
				// trace('after fork $idx:');
				// traceChoiceArray(choices);
				idx++;
			}
		}

		if (exprIndex < ast.length && ast[exprIndex].expr.match(EChoice(_))) {
			var allChoices = ast.collectChoices(exprIndex, weaveDepth).choices;
			for (choice in allChoices) {
				if (choicesTaken.indexOf(choice.id) == -1 || !choice.onceOnly) {
					switch (choice.condition) {
						case Some(expr):
							if (!hInterface.cond(expr, nodeScopes)) {
								continue;
							}
						case None:
					}
					if (!choice.output.isEmpty()) {
						choices.push(choice);
					}
				}
			}
		}

		// trace('final:');
		// traceChoiceArray(choices);

		// traceChoiceArray(choices);
		return choices;
	}

	private function fallbackChoice():FallbackChoice {
		var choiceInfo = ast.collectChoices(exprIndex, weaveDepth);
		var lastChoice = choiceInfo.choices[choiceInfo.choices.length - 1];
		if (lastChoice.output.isEmpty()) {
			return {choice: lastChoice, index: choiceInfo.fallbackIndex};
		} else {
			throw 'there is no fallback choice!';
		}
	}

	private function gotoNextGather() {
		var gatherIndex = ast.findNextGather(currentFile(), exprIndex + 1, weaveDepth);

		if (gatherIndex == -1) {
			throw 'Ran out of choice content, and there is no gather';
		}

		exprIndex = gatherIndex;
	}

	@:allow(hank.HankInterp)
	private function resolveNodeInScope(label:String, ?whichScope:Array<StoryNode>):Array<StoryNode> {
		if (whichScope == null)
			whichScope = nodeScopes;

		// Resolve the target's first part from the deepest current scope outwards
		var targetParts = label.split('.');

		var newScopes = [];
		for (i in 0...whichScope.length) {
			var scope = whichScope[i];
			switch (scope.resolve(targetParts[0])) {
				case Some(node):
					newScopes = whichScope.slice(i);
					newScopes.insert(0, node);
					// Then resolve the rest of the parts inward from there
					for (part in targetParts.slice(1)) {
						var scope = newScopes[0];
						switch (scope.resolve(part)) {
							case Some(innerNode):
								newScopes.insert(0, innerNode);
							case None:
								break;
						}
					}
					break;

				case None:
			}
		}
		return newScopes;
	}

	public function divertTo(target:String) {
		// Don't try to divert to a fallback target
		if (target.length == 0) {
			return;
		}
		switch (parent) {
			case Some(p) if (p.embedMode == Tunnel):
				// A divert from inside embedded hank, must leave the embedded context
				p.embeddedBlocks = [];
				p.divertTo(target);
				exprIndex = ast.length; // Must return finished
				return;
			default:
		}

		// trace('diverting to $target');

		var newScopes = if (target.startsWith("@")) {
			var parts = target.split('.');

			var root:Array<StoryNode> = cast hInterface.getVariable(parts[0].substr(1));
			if (parts.length > 1) {
				var subTarget = parts.slice(1).join('.');
				// trace(subTarget);
				resolveNodeInScope(subTarget, root);
			} else {
				root;
			};
		} else resolveNodeInScope(target);
		// trace('$target is $newScopes');

		if (newScopes == null // happens when a divert target variable doesn't exist
			|| newScopes.length == 0) // happens when target can't be resolved
			throw 'Divert target not found: $target';

		var targetIdx = newScopes[0].astIndex;

		if (targetIdx == null) {
			throw 'Divert target not found: $target';
		}
		// trace(targetIdx);

		// update the expression index
		exprIndex = targetIdx;
		var target = newScopes[0];
		weaveDepth = 0;

		// Update the view count
		switch (ast[exprIndex].expr) {
			case EKnot(_):
				// if it's a knot, increase its view count and increase index by one more
				viewCounts[target] += 1;

				exprIndex += 1;
				// If a knot directly starts with a stitch, run it
				switch (ast[exprIndex].expr) {
					case EStitch(label):
						var firstStitch = resolveNodeInScope(label, newScopes)[0];
						viewCounts[firstStitch] += 1;
						exprIndex += 1;
					default:
				}
				weaveDepth = 0;

			case EStitch(_):
				// if it's a stitch, increase its view count
				viewCounts[target] += 1;

				var enclosingKnot = newScopes[1];
				// If we weren't in the stitch's containing section before, increase its viewcount
				if (nodeScopes.indexOf(enclosingKnot) == -1) {
					viewCounts[enclosingKnot] += 1;
				}
				exprIndex += 1;
				weaveDepth = 0;

			case EChoice(c):
				storedFrame = Some(finalTextProcessing(evaluateChoice(c)));
				return;

			// Choices and gathers update their own view counts
			default:
		}
		// Update nodeScopes to point to the new scope
		nodeScopes = newScopes;
	}

	public function choose(choiceIndex:Int):String {
		var nf = nextFrame();
		if (!nf.match(HasChoices(_))) {
			throw 'Trying to make a choice when next frame is $nf';
		}
		// trace('choosing $choiceIndex');
		// If tunnel-embedded, let the proper embedded section evaluate the choice
		if (embeddedBlocks.length > 0 && embedMode == Tunnel) {
			return embeddedBlocks[0].choose(choiceIndex);
		} else {
			// if not embedded, actually make the choice. avalaibleChoices() accounts for aggregating threaded choices
			var output = evaluateChoice(availableChoices()[choiceIndex]);
			if (embedMode == Thread) {
				embedMode = Tunnel;
				embeddedBlocks = [];
			}

			return output;
		}
	}

	function evaluateChoice(choice:Choice):String {
		// if the choice has a label, increment its view count
		switch (choice.label) {
			case Some(l):
				var node = switch (resolveNodeInScope(l)) {
					case []:
						//  the choice is being diverted to, which means it's out of scope. Find it from the StoryTree's choice map another way
						storyTree.nodeForChoice(choice.id);

					case nodePath:
						nodePath[0];
				};

				viewCounts[node] += 1;
			case None:
		}
		weaveDepth = choice.depth + 1;
		// if the choice is onceOnly, add its id to the shit list
		if (choice.onceOnly) {
			choicesTaken.push(choice.id);
		}

		switch (choice.divertTarget) {
			case Some(t):
				divertTo(t);
			case None:
				exprIndex = ast.indexOfChoice(choice.id) + 1;
		}

		var output = choice.output.format(this, hInterface, random, altInstances, nodeScopes, true);
		return finalChoiceOutputProcessing(output);
	}

	/** Parse and run embedded Hank script on the fly. **/
	public function runEmbeddedHank(h:String, locals) {
		embedMode = Tunnel;
		embeddedBlocks.push(embeddedStory(h));
	}

	private function removeDoubleSpaces(t:String) {
		var intermediate = t;
		while (intermediate.indexOf('  ') != -1) {
			intermediate = intermediate.replace('  ', ' ');
		}
		return intermediate;
	}

	private function finalTextProcessing(t:String) {
		if (t.length > 0)
			return HasText(removeDoubleSpaces(t).trim());
		else
			return nextFrame();
	}

	private function finalChoiceOutputProcessing(t:String) {
		return removeDoubleSpaces(t).trim();
	}

	private function finalChoiceProcessing(choices:Array<String>) {
		return HasChoices([for (c in choices) removeDoubleSpaces(c).trim()]);
	}

	/**
		Classes and Enums can have dynamically specified behaviors for when they are embedded in Hank output.
	 */
	public function formatForInsertion(value:Dynamic):String {
		if (value == null) {
			throw 'Trying to format null for insertion!';
		}
		// Static extension syntax wasn't working here, probably because of type parameters
		var c = Type.getClass(value);
		var e = Type.getEnum(value);
		var typeName = if (c != null) {
			Type.getClassName(c);
		} else if (e != null) {
			Type.getEnumName(e);
		} else {
			null;
		}

		// trace(typeName);
		if (typeName != null && insertionHooks.exists(typeName)) {
			return insertionHooks[typeName](value);
		}

		// If no special hook is defined for the value to insert,
		return Std.string(value);
	}
}
