package console;

import haxe.macro.Expr.TypePath;
import haxe.macro.Context;
import haxe.macro.Expr.Field;

class ConsoleObjectConstructorMacro {
	macro static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var constructorfield = fields[0];
		var vmInstallExprs = [];
		var linkExprs = [];
		switch (constructorfield.kind) {
			case FVar(TPath(p), e):
				switch (e.expr) {
					case EArrayDecl(values):
						for (c in ConsoleObjectMacro.defClasses) {
							var p:TypePath = {
								pack: c.pack,
								name: c.name
							};
							values.push({
								pos: Context.currentPos(),
								expr: EBinop(OpArrow, macro $v{c.name}, macro() -> new $p())
							});
							var installExpr = macro {
								$i{c.name}.install(vmObj);
							};

							trace('Registering ${c.name} class constructor and namespace');

							vmInstallExprs.push(installExpr);

							if (c.superClass != null && c.superClass.t.get().name != "ConsoleObject") {
								var linkExpr = macro {
									vmObj.linkNamespaces($v{c.superClass.t.get().name}, $v{c.name});
								}
								linkExprs.push(linkExpr);
							}
						}
					case _:
						false;
				}
			case _:
				false;
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
					$b{vmInstallExprs} $b{linkExprs}
				}
			})
		}
		fields.push(insertFunc);
		return fields;
	}
}
