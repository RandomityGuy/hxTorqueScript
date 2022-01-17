package console;

import haxe.macro.TypeTools;
import haxe.macro.Expr.Field;
import haxe.macro.Context;

class ConsoleObjectMacro {
	public static var defClasses:Array<haxe.macro.Type.ClassType> = [];

	macro static function build():Array<Field> {
		defClasses.push(Context.getLocalClass().get());
		var fields = Context.getBuildFields();

		trace('Registering ${Context.getLocalClass().get().name} class methods');

		var vmInstallExprs = [];

		// Console method support
		for (field in fields) {
			switch (field.kind) {
				case FFun(f):
					if (field.meta != null) {
						for (meta in field.meta) {
							if (meta.name != ":consoleMethod")
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
										vmObj.addConsoleMethod($v{Context.getLocalClass().get().name}, $v{fnName}, $v{funUsage}, $v{minArgs}, $v{maxArgs},
											$i{retType + "CallbackType"}((vm, s, arr) -> $i{field.name}(vm, cast s, arr)));
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

		if (fields.filter(x -> x.name == "getClassName").length == 0) {
			var classNameField:Field = {
				name: "getClassName",
				pos: Context.currentPos(),
				access: [APublic, AOverride],
				kind: FFun({
					args: [],
					expr: macro {
						return $v{Context.getLocalClass().get().name};
					}
				})
			}
			fields.push(classNameField);

			var classNameVar:Field = {
				name: "assignClassName",
				pos: Context.currentPos(),
				access: [APrivate, AOverride],
				kind: FFun({
					args: [],
					expr: macro {
						this.className = $v{Context.getLocalClass().get().name};
					}
				})
			}
			fields.push(classNameVar);
		}

		return fields;
	}
}
