package hank;

using StringTools;
import haxe.ds.Option;

using Extensions.Extensions;

enum AltBehavior {
    Sequence;
    OnceOnly;
    Cycle;
    Shuffle;
}

@:allow(hank.AltInstance)
@:allow(hank.Output)
class Alt {
    var behavior: AltBehavior;
    var outputs: Array<Output>;

    static var behaviorMap = [
        '>' => Sequence,
        '!' => OnceOnly,
        '&' => Cycle,
        '~' => Shuffle,
        'sequence:' => Sequence,
        'once:' => OnceOnly,
        'cycle:' => Cycle,
        'shuffle:' => Shuffle
    ];

    public function new(behavior: AltBehavior, outputs: Array<Output>) {
        this.behavior = behavior;
        this.outputs = outputs;
    }

    public static function parse(buffer: HankBuffer): Option<Alt> {
        var rawExpr = buffer.findNestedExpression('{', '}').unwrap().checkValue();
	
        var expr = rawExpr.substr(1, rawExpr.length-2).ltrim();
	// trace (expr);

        // Sequences are the default behavior
        var behavior = Sequence;
        for (prefix in behaviorMap.keys()) {
            if (expr.startsWith(prefix)) {
                expr = expr.substr(prefix.length).trim();
                behavior = behaviorMap[prefix];
		break; // <-- Finally figured that one out.
            }
        }
	// trace (behavior);
        var outputsBuffer = HankBuffer.Dummy(expr);
        var eachOutputExpr = outputsBuffer.rootSplit('|');


	
        if (eachOutputExpr.length == 1) {
            return None; // If no pipe is present, it's not an alt
        }
	// There can't be newlines preceding the arms of alt expressions, or everything following the newline will disappear -- hence ltrim() below.
        var outputs = [for(outputExpr in eachOutputExpr) Output.parse(HankBuffer.Dummy(outputExpr.ltrim()), true)];

	// trace(outputs);

        buffer.take(rawExpr.length);
        return Some(new Alt(behavior, outputs));
    }
}

class AltInstance {
    var alt: Alt;
    var index: Int = -1;
    var random: Random;

    public function new(behavior: AltBehavior, outputs: Array<Output>, random: Random) {
        this.alt = new Alt(behavior, outputs);
        this.random = random;
    }

    public function next(): Output {
        switch (alt.behavior) {
            case Sequence:
                index = Math.floor(Math.min(alt.outputs.length-1, index+1));
            case OnceOnly:
                if (index >= -1) {
                    index = index+1;
                }
                if (index >= alt.outputs.length) index = -2;
            case Cycle:
                index = (index + 1) % alt.outputs.length;
            case Shuffle:
                // Pick a random index deterministically using the story's Random object.
                index = random.int(0, alt.outputs.length - 1);
        }
        return if (index < 0) new Output() else alt.outputs[index];
    }
}