package hank;

import haxe.ds.Option;

typedef Choice = {id: Int, onceOnly: Bool, label: Option<String>, condition: Option<String>, depth: Int, output: Output, divertTarget: Option<String>};

typedef ChoicePointInfo = {choices: Array<Choice>, fallbackIndex: Int};

typedef FallbackChoice = {choice: Choice, index: Int};