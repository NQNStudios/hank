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
}
