// This file is based on @Zicklag's gist: https://gist.github.com/zicklag/c2a6060452759ce13864e43135e856f3

package hank;

import hxparse.Lexer;
import hxparse.RuleBuilder;

enum HankToken {
    // Brackets
    TParenOpen;
    TParenClose;
    TSquareOpen;
    TSquareClose;
    TCurlyOpen;
    TCurlyClose;
    // Symbols
    TStar;
    TPlus;
    TDash;
    TBang;
    TTilde;
    TArrow;
    TEqual;
    TDoubleEqual;
    TTripleEqual;
    TGlue;
    TLineComment(s:String);
    TBlockComment(s:String);
    TNewline;
    // HInterface
    TBacktick;
    TTripleBacktick;
    TComma;
    TTripleComma;
    // Other
    TInclude(p:String);
    TWord(w:String);
    TEof;
}
class N {
    public static var n = 0;
}

/**
 Lexer for valid tokens inside a Hank script.
**/
class HankLexer extends Lexer implements RuleBuilder {
    static var buf: StringBuf;

    public static var tok = @:rule [
        // Brackets
        "\\(" => TParenOpen,
        "\\)" => TParenClose,
        "[" => TSquareOpen,
        "]" => TSquareClose,
        "{" => TCurlyOpen,
        "}" => TCurlyClose,
        // Symbols
        "\\*" => TStar,
        "+" => TPlus,
        "-" => TDash,
        "!" => TBang,
        "~" => TTilde,
        "->" => TArrow,
        "=" => TEqual,
        "==" => TDoubleEqual,
        "===" => TTripleEqual,
        "<>" => TGlue,
        "//" => {
            buf = new StringBuf();
            lexer.token(lineComment);
            TLineComment(buf.toString());
        },
        "/\\*" => {
            buf = new StringBuf();
            lexer.token(blockComment);
            TBlockComment(buf.toString());
        },
        "\n" => TNewline,
        // HInterface
        "`" => TBacktick,
        "```" => TTripleBacktick,
        "," => TComma,
        ",,," => TTripleComma,
        // Other
        "INCLUDE " => {
            buf = new StringBuf();
            lexer.token(include);
            TInclude(buf.toString());
        },
        "." => {
            buf = new StringBuf();
            lexer.token(word);
            TWord(buf.toString());
        },
        "" => TEof
    ];

    public static var lineComment = @:rule [
        '\n' => {
            lexer.curPos().pmax;
        },
        '[^"]' => {
			buf.add(lexer.current);
			lexer.token(lineComment);
        }
    ];

    public static var blockComment = @:rule [
        '\\*/' => {
            lexer.curPos().pmax;
        },
        '[^"]' => {
			buf.add(lexer.current);
			lexer.token(blockComment);
        }
    ];

    public static var include = @:rule [
        '\n' => {
            lexer.curPos().pmax;
        },
        ' ' => {
            lexer.curPos().pmax;
        },
        '[^"]' => {
			buf.add(lexer.current);
			lexer.token(include);
        }
    ];

    public static var word = @:rule [
        '\n' => {
            lexer.curPos().pmax;
        },
        ' ' => {
            lexer.curPos().pmax;
        },
        '[^"]' => {
			buf.add(lexer.current);
			lexer.token(include);
        }
    ];

}