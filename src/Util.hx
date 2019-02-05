package src;

class Util {
    /**
    Look for a pair of substrings that signal the opening and closing of a block, i.e. { and }.
    Returns the contents of the enclosure
     **/
    public static function findEnclosure(str: String, opening: String, closing: String): String {
        var start = str.indexOf(opening);
        if (start + opening.length >= str.length) {
            return null;
        }
        var end = str.indexOf(closing, start+opening.length);
        if (start != -1 && end != -1) {
            var contentsOfEnclosure = str.substr(start+opening.length, end - start - opening.length);
            // trace('Contents of enclosure: ${contentsOfEnclosure}');
            return contentsOfEnclosure;
        }
        return null;
    }

    public static function startsWithEnclosure(str: String, opening: String, closing:String): Bool {
        return str.indexOf(opening) == 0 && str.indexOf(closing) > 0;
    }

    public static function findEnclosureIfStartsWith(str: String, opening: String, closing: String): String {
        return if (startsWithEnclosure(str, opening, closing)) {
            findEnclosure(str, opening, closing);
        } else {
            '';
        }
    }

    public static function replaceEnclosure(str: String, rep: String, opening: String, closing: String): String {
        var start = str.indexOf(opening);
        if (start + opening.length >= str.length) {
            return str;
        }
        var end = str.indexOf(closing, start + opening.length);

        // trace('original: ${str}');
        var beforeEnc = str.substr(0, start);
        // trace('beforepart: ${beforeEnc}');
        var afterEnc = str.substr(end + closing.length);
        // trace('afterpart: ${afterEnc}');
        return beforeEnc + rep + afterEnc;
    }

    public static function containsEnclosure(str: String, opening: String, closing: String): Bool {
        var start = str.indexOf(opening);
        if (start + opening.length >= str.length) {
            return false;
        }
        var end = str.indexOf(closing,start+opening.length);

        return (start != -1 && end != -1);
    }

    public static function startsWithOneOf(str: String, prefixes: Array<String>) {
        for (prefix in prefixes) {
            if (StringTools.startsWith(str, prefix)) {
                return true;
            }
        }
        return false;
    }

    /**
    Strip whichever of the given prefix list comes first at the start of a string
    **/
    public static function stripPrefixes(str: String, prefixes: Array<String>) {
        for (prefix in prefixes) {
            if (str.indexOf(prefix) == 0) {
                str = StringTools.replace(str, prefix, '');
                return StringTools.trim(str);
            }
        }

        return str;
    }
}