package;

#if macro
import sys.io.File;
import haxe.macro.ExprTools;
import haxe.macro.Context;
import haxe.macro.Expr;

class JSGenMacro {
	macro static function embedLib():Array<Field> {
		var fields = Context.getBuildFields();
		var lib = File.getContent("bin/hxTorquescript.js");
		var libfield:Field = {
			name: "embedLib",
			pos: Context.currentPos(),
			kind: FVar(macro:String, macro $v{lib}),
			access: [APublic, AStatic]
		};
		fields.push(libfield);
		return fields;
	}
}
#end
