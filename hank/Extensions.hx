package hank;

using StringTools;
import haxe.ds.Option;
import hank.HankBuffer;

class Extensions {
	public static function unwrap<T>(o:Option<T>):T {
		switch (o) {
			case Some(value):
				return value;
			case None:
				throw 'Tried to unwrap a None value.';
		}
	}

	// This is borrowed from https://stackoverflow.com/a/32856707
	public static function toIterable<T>(i:Void->Iterator<T>): Iterable<T> {
		return { iterator: i };
	}

	public static function tokenize(s: String): Array<String> {
		var tokenStartIndices = [ ];
		var whitespaceIndices = [ ];
		var tokens = [ ];
		var lastWasChar = false;
		s = s.trim();

		for (i in 0...s.length) {
			if (s.isSpace(i)) {
				lastWasChar = false;
				if (lastWasChar) whitespaceIndices.push(i);
			}
			else {
				if (!lastWasChar) tokenStartIndices.push(i);
				lastWasChar = true;
			}
		}
		
		whitespaceIndices.push(null); // This ensures the last token will substr() correctly

		return [for (i in 0...tokenStartIndices.length) s.substr(tokenStartIndices[i], whitespaceIndices[i])];
	}
}
