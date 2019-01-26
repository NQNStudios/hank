package tests;

import utest.Test;
import utest.Assert;
import hank.Alt.AltBehavior;
import hank.Alt.AltState;
import hank.Random.Random;

class AltTest extends utest.Test {

    public function testSequence1() {
        var seq = new AltState(Sequence, ['series', 'of', 'words'], new Random());
        Assert.equals('series', seq.next());
        Assert.equals('of', seq.next());
        Assert.equals('words', seq.next());
        Assert.equals('words', seq.next());
        Assert.equals('words', seq.next());
    }

    public function testOnceOnly() {
        var seq = new AltState(OnceOnly, ['series', 'of', 'words'], new Random());
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
        var seq = new AltState(Cycle, ['series', 'of', 'words'], new Random());
        Assert.equals('series', seq.next());
        Assert.equals('of', seq.next());
        Assert.equals('words', seq.next());
        Assert.equals('series', seq.next());
        Assert.equals('of', seq.next());
        Assert.equals('words', seq.next());
        Assert.equals('series', seq.next());
    }
}    