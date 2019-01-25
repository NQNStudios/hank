package src;

import haxe.ds.Option;

typedef Choice = {
    var label: Option<String>;
    var expires: Bool;
    var text: String;
    var depth: Int;
    // Choices are parsed with a unique ID so they can be followed even if duplicate text is used for multiple choices
    var id: Int;
    // Choices can be declared with a divert target on the same line. That target will be stored in this optional field.
    var divertTarget: Option<String>;
}

