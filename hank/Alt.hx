package hank;

enum AltBehavior {
    Sequence;
    OnceOnly;
    Cycle;
    Shuffle;
}

typedef Alt = {
    var behavior: AltBehavior;
    var outputs: Array<Output>;
}

class AltInstance {
    var alt: Alt;
    var index: Int = -1;
    var random: Random;

    public function new(behavior: AltBehavior, outputs: Array<Output>, random: Random) {
        this.alt = {
            behavior: behavior,
            outputs: outputs
        };
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