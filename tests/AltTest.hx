package tests;

import utest.Test;
import utest.Assert;
import src.Alt.AltBehavior;
import src.Alt.AltState;

class AltTest extends utest.Test {

    public function testSequence1() {
        var seq = new AltState(Sequence, ['series', 'of', 'words']);
        Assert.equals('series', seq.next());
        Assert.equals('of', seq.next());
        Assert.equals('words', seq.next());
        Assert.equals('words', seq.next());
        Assert.equals('words', seq.next());
    }

    public function testOnceOnly() {
        var seq = new AltState(OnceOnly, ['series', 'of', 'words']);
        Assert.equals('series', seq.next());
        Assert.equals('of', seq.next());
        Assert.equals('words', seq.next());
        Assert.equals('', seq.next());
        Assert.equals('', seq.next());
        Assert.equals('', seq.next());
        Assert.equals('', seq.next());
        Assert.equals('', seq.next());
        Assert.equals('', seq.next());
        Assert.equals('', seq.next());
    }
      
    public function testCycle() {
        var seq = new AltState(Cycle, ['series', 'of', 'words']);
        Assert.equals('series', seq.next());
        Assert.equals('of', seq.next());
        Assert.equals('words', seq.next());
        Assert.equals('series', seq.next());
        Assert.equals('of', seq.next());
        Assert.equals('words', seq.next());
        Assert.equals('series', seq.next());
    }
}    