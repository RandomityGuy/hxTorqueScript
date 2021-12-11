package;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class Main {
	static var successFiles = 0;
	static var failedFiles = 0;

	static public function main():Void {
		execDirectory("tests");
		trace('Parsed ${successFiles} files out of ${successFiles + failedFiles} files');

		// var f = File.getContent("main.cs");
		// var scanner = new Scanner(f);
		// var toks = scanner.scanTokens();
		// var parser = new Parser(toks);
		// var stmts = parser.parse();
	}

	static public function execDirectory(path:String) {
		var files = FileSystem.readDirectory(path);

		for (file in files) {
			if (FileSystem.isDirectory(path + '/' + file)) {
				execDirectory(path + '/' + file);
			} else {
				if (Path.extension(file) == 'cs' || Path.extension(file) == 'gui' || Path.extension(file) == 'mis' || Path.extension(file) == "mcs") {
					var f = File.getContent(path + '/' + file);
					var scanner = new Scanner(f);
					try {
						var toks = scanner.scanTokens();
						var parser = new Parser(toks);
						var stmts = parser.parse();
						trace('Parsed ${stmts.length} statements for ${file} (${toks.length} tokens)');
						successFiles++;
					} catch (e) {
						trace('Failed parsing ${file}');
						failedFiles++;
					}
				}
			}
		}
	}
}
