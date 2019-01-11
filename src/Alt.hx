package src;

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
    public function new(behavior: AltBehavior, alts: Array<String>) {
        this.behavior = behavior;
        this.alts = alts;
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
                // TODO use a seeded random.
                index = Math.floor(Math.random() * alts.length);
        }
        return if (index < 0) '' else alts[index];
    }
}