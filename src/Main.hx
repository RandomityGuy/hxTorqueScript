package;

import haxe.EnumFlags;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class Main {
	static var successFiles = 0;
	static var failedFiles = 0;

	static var disasmVerbosity:haxe.EnumFlags<Disassembler.DisassemblyVerbosity> = new EnumFlags<Disassembler.DisassemblyVerbosity>();

	static public function main():Void {
		var args = Sys.args();
		var oLevel = 3;

		disasmVerbosity.set(Disassembler.DisassemblyVerbosity.Code);
		disasmVerbosity.set(Disassembler.DisassemblyVerbosity.Args);
		disasmVerbosity.set(Disassembler.DisassemblyVerbosity.ConstTables);
		disasmVerbosity.set(Disassembler.DisassemblyVerbosity.ConstTableReferences);

		if (args.length == 0) {
			Sys.println("Usage: ");
			Sys.println("hxTorqueScript <path/directory> [-d] [-v[atr]]");
			Sys.println("-d: disassemble");
			Sys.println("-v: a: args t: const tables r: const table references");
			Sys.println("-r: run dso");
		} else {
			var path = args[0];

			var isRun = false;

			var isDisassemble = false;
			if (args.length > 1) {
				if (args[1] == "-d") {
					isDisassemble = true;
				}

				if (args[1] == "-r") {
					isRun = true;
				}

				if (args[1].substring(0, 2) == '-O') {
					oLevel = Std.parseInt(args[1].substring(2));
				}

				if (args.length > 2) {
					if (args[2].substring(0, 2) == "-v") {
						var chrs = args[2].substring(2);
						disasmVerbosity = new EnumFlags<Disassembler.DisassemblyVerbosity>();
						disasmVerbosity.set(Disassembler.DisassemblyVerbosity.Code);

						for (i in 0...chrs.length) {
							if (chrs.charAt(i) == "a") {
								disasmVerbosity.set(Disassembler.DisassemblyVerbosity.Args);
							}
							if (chrs.charAt(i) == "t") {
								disasmVerbosity.set(Disassembler.DisassemblyVerbosity.ConstTables);
							}
							if (chrs.charAt(i) == "r") {
								disasmVerbosity.set(Disassembler.DisassemblyVerbosity.ConstTableReferences);
							}
						}
					}
				}
			}

			if (FileSystem.isDirectory(path)) {
				if (isDisassemble)
					disasmDirectory(path);
				else if (!isRun)
					execDirectory(path, oLevel);
			} else {
				if (isDisassemble)
					disasmFile(path);
				else if (!isRun)
					execFile(path);
				else
					runFile(path);
			}
		}

		// execDirectory("tests");
		// disasmDirectory("tests");
		// parseDirectory("mb");
		// parseDirectory("D:/Marbleblast/PQ-src/Build/Cache/PQ/Marble Blast Platinum");
		trace('Ran actions on ${successFiles} files out of ${successFiles + failedFiles} files');

		// var f = File.getContent("mb/marble/client/scripts/client.cs");
		// var compiler = new Compiler();
		// compiler.compile(f);

		// var f = File.getBytes("mb/marble/client/scripts/client.cs.dso");
		// var disam = new Disassembler();
		// disam.load(new BytesInput(f));
		// disam.disassembleCode();
	}

	static public function execDirectory(path:String, optimizeLevel:Int) {
		var files = FileSystem.readDirectory(path);

		for (file in files) {
			if (FileSystem.isDirectory(path + '/' + file)) {
				execDirectory(path + '/' + file, optimizeLevel);
			} else {
				if (Path.extension(file) == 'cs' || Path.extension(file) == 'gui' || Path.extension(file) == 'mcs') {
					var f = File.getContent(path + '/' + file);
					// try {
					var compiler = new Compiler();
					var bytesB = compiler.compile(f, optimizeLevel);
					File.saveBytes(path + '/' + file + '.dso', bytesB.getBytes());
					trace('Compiled ${path}/${file}');
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
		// try {
		var compiler = new Compiler();
		var bytesB = compiler.compile(f);
		File.saveBytes(path + '.dso', bytesB.getBytes());
		successFiles++;
		// } catch (e) {
		// 	trace('Failed compiling ${path}');
		// 	trace(e.toString());
		// 	failedFiles++;
		// }
	}

	static public function runFile(path:String) {
		var f = File.getBytes(path);
		// try {
		var vm = new VM();
		vm.exec(path);
		// } catch (e) {
		// 	trace('Failed compiling ${path}');
		// 	trace(e.toString());
		// 	failedFiles++;
		// }
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
						trace('Disassembled ${path}/${file}');
						File.saveContent(path + '/' + file + '.disasm', dism.writeDisassembly(dcode, disasmVerbosity));
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
		// try {
		var dism = new Disassembler();
		dism.load(new BytesInput(f));
		var dcode = dism.disassembleCode();
		File.saveContent(path + '.disasm', dism.writeDisassembly(dcode, disasmVerbosity));
		successFiles++;
		// } catch (e) {
		// 	trace('Failed disassembling ${path}');
		// 	trace(e.toString());
		// 	failedFiles++;
		// }
	}
}
