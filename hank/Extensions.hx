package hank;

import haxe.ds.Option;

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
}
