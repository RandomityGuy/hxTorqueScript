package;

#if macro
import haxe.macro.Compiler;
import sys.io.File;
import haxe.macro.Context;

class BuildMacro {
	public static function build() {
		Context.onAfterGenerate(() -> {
			trace("Bootstrapping js");
			var contents = File.getContent(Compiler.getOutput());
			contents = StringTools.replace(contents, "__EMBED_LIB__", Scanner.escape(contents));
			File.saveContent(Compiler.getOutput(), contents);
		});
	}
}
#end
