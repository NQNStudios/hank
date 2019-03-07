package tests;

import haxe.io.Bytes;
import sys.io.File;
import byte.ByteData;

import utest.Test;
import utest.Assert;

import hxparse.LexerTokenSource;

import hank.HankLexer;


class HankLexerTest extends utest.Test {
    
    public function testLexMainExample() {
        trace('constructing');
        var lexer = new HankLexer(ByteData.ofString(File.getContent('examples/main/main.hank')), 'testScript');
        var ts = new LexerTokenSource(lexer, HankLexer.tok);
        trace(ts.token());
    }
}