package hank;

import haxe.ds.Option;

typedef Choice = {id:Int, onceOnly:Bool, label:Option<String>, condition:Option<String>, depth:Int, output:Output, divertTarget:Option<String>};
typedef ChoiceInfo = {choice: Choice, tags: Array<String>};
typedef ChoicePointInfo = {choices:Array<ChoiceInfo>, fallbackIndex:Int};
typedef FallbackChoiceInfo = {choiceInfo:ChoiceInfo, index:Int};

class ChoiceExtension {
	public static function toString(choice:Choice):String {
		return '*' + Std.string(choice.output.parts[0]) + '...';
	}
}
