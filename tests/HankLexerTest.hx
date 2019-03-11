package tests;

import sys.io.File;
import byte.ByteData;

import utest.Test;

import hxparse.LexerTokenSource;

import hank.HankLexer;
import hank.HankLexer.HankToken;

import tests.HankAssert;

class HankLexerTest extends utest.Test {

    var nextSaved: HankToken = null;

    /**
     Helper: Retrieve the next meaningful lexer token (non-whitespace, non-text)
    **/
    function next(ts: LexerTokenSource) {
        if (nextSaved != null) {
            var temp = nextSaved;
            nextSaved = null;
            return temp;
        }
        var text = '';
        var token: HankToken;
        do {
            switch (token) {
                case TChar(c):
                    text += c;
            }
            
        } while(true);


        switch (ts.next()) {
            case TCh
            other =>
        }
    }
    
    public function testLexMainExample() {
        var lexer = new HankLexer(ByteData.ofString(File.getContent('examples/main/main.hank')), 'testScript');
        var ts = new LexerTokenSource(lexer, HankLexer.tok);
        HankAssert.equals(TInclude("extra.hank"), ts.token());
        HankAssert.equals(TNewline, ts.token());
        HankAssert.equals(TArrow, ts.token());
        HankAssert.equals(TWhitespace, ts.token());
        HankAssert.equals(TWord("start"), ts.token());
        HankAssert.equals(TLineComment(" This syntax moves the game flow to a new section."), ts.token());
        for (i in 0...100) {
            trace(ts.token());
        }
    }
}