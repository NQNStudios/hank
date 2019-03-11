package tests;

import haxe.io.Bytes;
import sys.io.File;
import byte.ByteData;

import utest.Test;
import utest.Assert;

import hxparse.LexerTokenSource;

import hank.HankLexer;
import hank.HankLexer.HankToken;

import tests.HankAssert;

class HankLexerTest extends utest.Test {
    
    public function testLexMainExample() {
        var lexer = new HankLexer(ByteData.ofString(File.getContent('examples/main/main.hank')), 'testScript');
        var ts = new LexerTokenSource(lexer, HankLexer.tok);
        HankAssert.equals(TInclude("extra.hank"), ts.token());
        HankAssert.equals(TNewline, ts.token());
        HankAssert.equals(TArrow, ts.token());
        HankAssert.equals(TWord("start"), ts.token());
        HankAssert.equals(TLineComment(" This syntax moves the game flow to a new section."), ts.token());
        for (i in 0...100) {
            trace(ts.token());
        }
    }
}