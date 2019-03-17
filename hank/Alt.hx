package hank;

import haxe.ds.Option;
using Extensions.OptionExtender;

enum AltBehavior {
    Sequence;
    OnceOnly;
    Cycle;
    Shuffle;
}

@:allow(hank.AltInstance)
class Alt {
    var behavior: AltBehavior;
    var outputs: Array<Output>;

    static var behaviorMap = [
        '>' => Sequence,
        '!' => OnceOnly,
        '&' => Cycle,
        '~' => Shuffle,
        'seq:' => Sequence,
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
        var expr = rawExpr.substr(1, rawExpr.length-2);

        for (prefix in behaviorMap.keys()) {
            if (StringTools.startsWith(expr, prefix)) {
                var _outputs = StringTools.trim(expr.substr(prefix.length));

                buffer.take(rawExpr.length);
                return Some(new Alt(behaviorMap[prefix], []));
            }
        }

        return None;
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