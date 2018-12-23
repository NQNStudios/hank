# hank
Minimal narrative scripting language based on Ink.

Hank is a more portable answer to Inkle's open-source [Ink](http://github.com/inkle/ink)
engine. It is currently just a proof of concept, but you may use it at your own risk.

## Comparison with Ink and Inkjs

|Feature|Ink|Inkjs|Hank|
|-------|---|-----|----|
|Well-maintained/Production-ready|Yes|Mostly yes|Maybe someday--probably never|
|Recommended external engines|Unity| |HaxeFlixel|
|Ease of use|Comes with the Inky editor, gives syntax hints. Thriving, helpful community.|Easily embeds in web-pages. Partly supported by Inkle.|Stricter syntax, no official editor. Only understood by one other person (for now)|
|Flexible scripting|Powerful but bulky embedded scripting system|I'm not sure|Uses [hscript](https://github.com/HaxeFoundation/hscript) module to allow full Haxe expressions inline without scope bloat|
|Open-source purism|Tightly coupled with Unity|Compatible with the Javascript webdev ecosystem|Death/bankruptcy before closed-source dependencies|
|Automatic testing|Not sure|None|Write expected transcripts to easily test your story's output given sets of choices|
|Playthrough transcript exporting|None|None|Coming Soon|
|Toolchain completeness|Inky & Unity plugin use the official compiler to recompile automatically while you edit|Relies on running the official compiler before each time compiling your webgame|Parses and runs entirely at runtime without external compiler|
|Publishing for Desktop app|Supported through Unity|Theoretically possible with Electron|Coming soon with HaxeFlixel|
|Publishing for Mobile app|Supported through Unity|Not sure if possible|Coming soon with HaxeFlixel|
|Publishing for HTML5|Supported through Unity|Supported out of the box|Coming soon with HaxeFlixel|
|Publishing for AAA Consoles|Supported through Unity|Likely impossible|Coming soon with HaxeFlixel|

As of now, you are better off using Ink or Inkjs for serious gamedev. Hank is good if you're interested in hacking away at a new/leaner system as a side project.

## Dependencies

```
haxelib install hx3compat
haxelib install hscript
```

## Build/Install

TODO

## Debug Hank stories

TODO
