package hank;

import haxe.CallStack;

class LogUtil {
  public static function prettifyStack(stack: Array<StackItem>) {
    var output = '';
    var lastFile: String = '';
    var linesFromFile = '';
    for (item in stack) {
      switch (item) {
      case FilePos(method, file, line):
        var relevantPart = Std.string(if (method != null) method else line);
        if (file != lastFile) {
          lastFile = file;
          output += linesFromFile + '\n';

          linesFromFile = '$file:$relevantPart';
        } else {
          linesFromFile += ':$relevantPart';
        }
      case other:
        trace('Stack contains unsupported element: $other');
        trace(stack);
      }
    }
    if (linesFromFile.length > 0) {
      output += linesFromFile + '\n';
    }
    return output;
  }


  public static function prettyPrintStack(stack: Array<StackItem>) {
    trace(prettifyStack(stack));    
  }

  public static macro function watch(e: Expr): Expr {
    switch (e.expr) {
        case EConst(CIdent(i)):
            return macro trace('$i:' + $e);
        default:
            throw 'Can only watch variables (for now)';
    }
  }

  public static function currentTarget(): String {
#if js
    return "js";
#end
#if cpp
    return "cpp";
#end
#if interp
    return "interp";
#end

#if neko
    return "neko";
#end

    return "unknown";

  }
}