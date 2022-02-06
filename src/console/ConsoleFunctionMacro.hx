package console;

import haxe.macro.ComplexTypeTools;
import haxe.macro.ExprTools;
import haxe.macro.Expr.TypePath;
import haxe.macro.Context;
import haxe.macro.Expr.Field;

enum CFFunctionType {
	IntCallbackType(callback:(Any, Array<String>) -> Int);
	FloatCallbackType(callback:(Any, Array<String>) -> Float);
	StringCallbackType(callback:(Any, Array<String>) -> String);
	VoidCallbackType(callback:(Any, Array<String>) -> Void);

	BoolCallbackType(callback:(Any, Array<String>) -> Bool);
}

typedef CFMacroFunc = {
	def:CFFunctionType,
	funUsage:String,
	minArgs:Int,
	maxArgs:Int
}

class ConsoleFunctionMacro {
	macro static function build():Array<Field> {
		var fields = Context.getBuildFields();

		var vmInstallExprs = [];

		for (field in fields) {
			switch (field.kind) {
				case FFun(f):
					if (field.meta != null) {
						for (meta in field.meta) {
							if (meta.name != ":consoleFunction")
								continue;

							var fnName = field.name;
							var funUsage:String = "";
							var minArgs = 0;
							var maxArgs = 0;
							for (param in meta.params) {
								switch (param.expr) {
									case EBinop(OpAssign, {expr: EConst(CIdent("usage"))}, {expr: EConst(CString(s, kind))}):
										funUsage = s;
									case EBinop(OpAssign, {expr: EConst(CIdent("minArgs"))}, {expr: EConst(CInt(v))}):
										minArgs = Std.parseInt(v);
									case EBinop(OpAssign, {expr: EConst(CIdent("maxArgs"))}, {expr: EConst(CInt(v))}):
										maxArgs = Std.parseInt(v);
									case EBinop(OpAssign, {expr: EConst(CIdent("name"))}, {expr: EConst(CString(s, kind))}):
										fnName = s;
									case _:
										continue;
								}
							}

							switch (f.ret) {
								case TPath({name: retType}):
									var installExpr = macro {
										vmObj.addConsoleFunction($v{fnName}, $v{funUsage}, $v{minArgs}, $v{maxArgs},
											$i{retType + "CallbackType"}((vm, s, arr) -> $i{field.name}(vm, s, arr)));
									}
									vmInstallExprs.push(installExpr);
								case _:
									continue;
							}
						}
					}
				case _:
					false;
			}
		}

		var insertFunc:Field = {
			name: "install",
			pos: Context.currentPos(),
			access: [APublic, AStatic],
			kind: FFun({
				args: [
					{
						name: "vm",
						opt: false
					}
				],
				expr: macro {
					var vmObj:VM = $i{"vm"};
					$b{vmInstallExprs}
				}
			})
		}
		fields.push(insertFunc);
		return fields;
	}
}
