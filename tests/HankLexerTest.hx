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
    }
}