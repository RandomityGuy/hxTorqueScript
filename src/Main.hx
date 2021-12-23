package;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class Main {
	static var successFiles = 0;
	static var failedFiles = 0;

	static public function main():Void {
		var args = Sys.args();

		if (args.length == 0) {
			Sys.println("Usage: ");
			Sys.println("hxTorqueScript <path/directory> [-d]");
			Sys.println("-d: disassemble");
		} else {
			var path = args[0];

			var isDisassemble = false;
			if (args.length > 1) {
				if (args[1] == "-d") {
					isDisassemble = true;
				}
			}

			if (FileSystem.isDirectory(path)) {
				if (isDisassemble)
					disasmDirectory(path);
				else
					execDirectory(path);
			} else {
				if (isDisassemble)
					disasmFile(path);
				else
					execFile(path);
			}
		}

		// execDirectory("tests");
		// disasmDirectory("tests");
		// parseDirectory("mb");
		// parseDirectory("D:/Marbleblast/PQ-src/Build/Cache/PQ/Marble Blast Platinum");
		// trace('Compiled ${successFiles} files out of ${successFiles + failedFiles} files');

		// var f = File.getContent("mb/marble/client/scripts/client.cs");
		// var compiler = new Compiler();
		// compiler.compile(f);

		// var f = File.getBytes("mb/marble/client/scripts/client.cs.dso");
		// var disam = new Disassembler();
		// disam.load(new BytesInput(f));
		// disam.disassembleCode();
	}

	static public function execDirectory(path:String) {
		var files = FileSystem.readDirectory(path);

		for (file in files) {
			if (FileSystem.isDirectory(path + '/' + file)) {
				execDirectory(path + '/' + file);
			} else {
				if (Path.extension(file) == 'cs' || Path.extension(file) == 'gui') {
					var f = File.getContent(path + '/' + file);
					// try {
					var compiler = new Compiler();
					var bytesB = compiler.compile(f);
					File.saveBytes(path + '/' + file + '.dso', bytesB.getBytes());
					successFiles++;
					// } catch (e) {
					// 	trace('Failed compiling ${file}');
					// 	failedFiles++;
					// }
				}
			}
		}
	}

	static public function execFile(path:String) {
		var f = File.getContent(path);
		try {
			var compiler = new Compiler();
			var bytesB = compiler.compile(f);
			File.saveBytes(path + '.dso', bytesB.getBytes());
			successFiles++;
		} catch (e) {
			trace('Failed compiling ${path}');
			trace(e.toString());
			failedFiles++;
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
					try {
						var scanner = new Scanner(f);
						var toks = scanner.scanTokens();
						var parser = new Parser(toks);
						var exprs = parser.parse();
						successFiles++;
					} catch (e) {
						trace('Failed parsing ${file}');
						failedFiles++;
					}
				}
			}
		}
	}

	static public function disasmDirectory(path:String) {
		var files = FileSystem.readDirectory(path);

		for (file in files) {
			if (FileSystem.isDirectory(path + '/' + file)) {
				disasmDirectory(path + '/' + file);
			} else {
				if (Path.extension(file) == 'dso') {
					var f = File.getBytes(path + '/' + file);
					try {
						var dism = new Disassembler();
						dism.load(new BytesInput(f));
						var dcode = dism.disassembleCode();
						File.saveContent(path + '/' + file + '.disasm', dism.writeDisassembly(dcode));
						successFiles++;
					} catch (e) {
						trace('Failed disassembling ${file}');
						failedFiles++;
					}
				}
			}
		}
	}

	static public function disasmFile(path:String) {
		var f = File.getBytes(path);
		try {
			var dism = new Disassembler();
			dism.load(new BytesInput(f));
			var dcode = dism.disassembleCode();
			File.saveContent(path + '.disasm', dism.writeDisassembly(dcode));
			successFiles++;
		} catch (e) {
			trace('Failed disassembling ${path}');
			trace(e.toString());
			failedFiles++;
		}
	}
}
