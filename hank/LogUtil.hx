package hank;

import haxe.CallStack;

class LogUtil {
  public static function prettyPrintStack(stack: Array<StackItem>) {
    var lastFile: String = '';
    var linesFromFile = '';
    for (item in stack) {
      switch (item) {
      case FilePos(null, file, line):
	if (file != lastFile) {
	  lastFile = file;
	  trace(linesFromFile);
	  linesFromFile = '$file:$line';
	} else {
	  linesFromFile += ':$line';
	}
      case other:
	trace('Stack contains unsupported element: $other');
	trace(stack);
      }
    }
  }
}