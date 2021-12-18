package;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class Main {
	static var successFiles = 0;
	static var failedFiles = 0;

	static public function main():Void {
		// execDirectory("tests");
		// parseDirectory("mb");
		// parseDirectory("D:/Marbleblast/PQ-src/Build/Cache/PQ/Marble Blast Platinum");
		// trace('Compiled ${successFiles} files out of ${successFiles + failedFiles} files');

		var f = File.getContent("tests/package.cs");
		var compiler = new Compiler();
		compiler.compile(f);
	}

	static public function execDirectory(path:String) {
		var files = FileSystem.readDirectory(path);

		for (file in files) {
			if (FileSystem.isDirectory(path + '/' + file)) {
				execDirectory(path + '/' + file);
			} else {
				if (Path.extension(file) == 'cs' || Path.extension(file) == 'gui') {
					var f = File.getContent(path + '/' + file);
					try {
						var compiler = new Compiler();
						var bytesB = compiler.compile(f);
						File.saveBytes(path + '/' + file + '.dso', bytesB.getBytes());
						successFiles++;
					} catch (e) {
						trace('Failed compiling ${file}');
						failedFiles++;
					}
				}
			}
		}
	}

	static public function parseDirectory(path:String) {
		var files = FileSystem.readDirectory(path);

		for (file in files) {
			if (FileSystem.isDirectory(path + '/' + file)) {
				parseDirectory(path + '/' + file);
			} else {
				if (Path.extension(file) == 'cs' || Path.extension(file) == 'gui') {
					var f = File.getContent(path + '/' + file);
					// try {
					var scanner = new Scanner(f);
					var toks = scanner.scanTokens();
					var parser = new Parser(toks);
					var exprs = parser.parse();
					successFiles++;
					// } catch (e) {
					// 	trace('Failed parsing ${file}');
					// 	failedFiles++;
					// }
				}
			}
		}
	}
}
