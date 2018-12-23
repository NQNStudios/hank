package src;

class Util {
    /**
    Look for a pair of substrings that signal the opening and closing of a block, i.e. { and }.
    Returns the contents of the enclosure
     **/
    public static function findEnclosure(str: String, opening: String, closing: String): String {
        var start = str.indexOf(opening);
        var end = str.indexOf(closing);
        if (start != -1 && end > start) {
            return str.substr(start+opening.length, end - start - opening.length);
        }
        return null;
    }

    public static function startsWithEnclosure(str: String, opening: String, closing:String): Bool {
        return str.indexOf(opening) == 0 && str.indexOf(closing) > 0;
    }

    public static function replaceEnclosure(str: String, rep: String, opening: String, closing: String): String {
        var start = str.indexOf(opening);
        var end = str.indexOf(closing);

        // trace('original: ${str}');
        var beforeEnc = str.substr(0, start);
        // trace('beforepart: ${beforeEnc}');
        var afterEnc = str.substr(end + closing.length);
        // trace('afterpart: ${afterEnc}');
        return beforeEnc + rep + afterEnc;
    }

    public static function containsEnclosure(str: String, opening: String, closing: String): Bool {
        var start = str.indexOf(opening);
        var end = str.indexOf(closing);

        return (start != -1 && end > start);
    }
}