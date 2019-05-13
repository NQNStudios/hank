package hank;

import haxe.CallStack;

class LogUtil {
  public static function prettyPrintStack(stack: Array<StackItem>) {
    var lastFile: String = '';
    var linesFromFile = '';
    for (item in stack) {
      switch (item) {
      case FilePos(method, file, line):
        var relevantPart = Std.string(if (method != null) method else line);
        if (file != lastFile) {
          lastFile = file;
          trace(linesFromFile);

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
      trace(linesFromFile);
    }
  }

}