package;

import console.ConsoleObjectConstructors;
import console.MathFunctions;
import console.ConsoleFunctions;
import haxe.macro.Compiler;
import sys.io.File;
import haxe.macro.Context;
import haxe.Template;
import haxe.Resource;

class ConsoleDoc {
	public static function main() {
		var args = Sys.args();
		var template = new Template(File.getContent(args[0]));
		var cfdocs = ConsoleFunctions.gatherDocs();
		var mdocs = MathFunctions.gatherDocs();
		var cdocs = ConsoleObjectConstructors.gatherDocs();
		var doc = template.execute({confuncs: cfdocs, mathfuncs: mdocs, conclasses: cdocs});
		File.saveContent(StringTools.replace(args[0], "-template", ""), doc);
	}
}
