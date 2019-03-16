package hank;

enum AltBehavior {
    Sequence;
    OnceOnly;
    Cycle;
    Shuffle;
}

class AltState {
    var behavior: AltBehavior;
    var index: Int = -1;
    var alts: Array<String>;
    var random: Random;

    public function new(behavior: AltBehavior, alts: Array<String>, random: Random) {
        this.behavior = behavior;
        this.alts = alts;
        this.random = random;
    }

    public function next() {
        switch (behavior) {
            case Sequence:
                index = Math.floor(Math.min(alts.length-1, index+1));
            case OnceOnly:
                if (index >= -1) {
                    index = index+1;
                }
                if (index >= alts.length) index = -2;
            case Cycle:
                index = (index + 1) % alts.length;
            case Shuffle:
                // Pick a random index deterministically using the story's Random object.
                index = random.int(0, alts.length - 1);
        }
        return if (index < 0) '' else alts[index];
    }
}