package hank;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.Serializer;
 
class FileLoadingMacro {
    public static macro function build(files: Array<String>): Array<Field> {
        var fields = Context.getBuildFields();

        var files = [for (file in files) file => sys.io.File.getContent(file)];
        var serializer = new Serializer();
        serializer.serialize(files);

        var filesField = {
            name: "_serializedFiles",
            doc: null,
            meta: [],
            access: [AStatic, APrivate],
            kind: FVar(macro : String, {expr: EConst(CString(serializer.toString())), pos: Context.currentPos()}),
            pos: Context.currentPos()
        };

        fields.push(filesField);
        return fields;
    }

    
}