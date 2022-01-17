package console;

import haxe.io.BytesInput;
import sys.io.File;
import sys.FileSystem;

@:build(console.ConsoleFunctionMacro.build())
class ConsoleFunctions {
	@:consoleFunction(usage = "echo(value, ...)", minArgs = 2, maxArgs = 0)
	static function echo(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		Sys.println(args.slice(1).join(""));
	}

	@:consoleFunction(usage = "activatePackage(package)", minArgs = 2, maxArgs = 2)
	static function activatePackage(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		vm.activatePackage(args[1]);
	}

	@:consoleFunction(usage = "deactivatePackage(package)", minArgs = 2, maxArgs = 2)
	static function deactivatePackage(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		vm.deactivatePackage(args[1]);
	}

	@:consoleFunction(usage = "compile(fileName)", minArgs = 2, maxArgs = 2)
	static function compile(vm:VM, thisObj:SimObject, args:Array<String>):Bool {
		var f = args[1];
		if (!FileSystem.exists(f)) {
			Sys.println('exec: invalid script file ${f}');
			return false;
		}
		var compiler = new Compiler();
		Sys.println('Compiling ${f}...');
		var dso = compiler.compile(File.getContent(f));
		File.saveBytes(f + '.dso', dso.getBytes());
		return true;
	}

	@:consoleFunction(usage = "exec(fileName)", minArgs = 2, maxArgs = 2)
	static function exec(vm:VM, thisObj:SimObject, args:Array<String>):Bool {
		var f = args[1];
		if (!FileSystem.exists(f) && !FileSystem.exists(f + '.dso')) {
			Sys.println('exec: invalid script file ${f}');
			return false;
		}
		if (FileSystem.exists(f)) {
			var compiler = new Compiler();
			Sys.println('Compiling ${f}...');
			var dso = compiler.compile(File.getContent(f));
			File.saveBytes(f + '.dso', dso.getBytes());
		}

		if (FileSystem.exists(f + '.dso')) {
			Sys.println('Loading compiled script ${f}.');
			vm.exec(f);
		}

		return true;
	}

	@:consoleFunction(usage = "eval(consoleString)", minArgs = 2, maxArgs = 2)
	static function eval(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var compiler = new Compiler();
		try {
			var bytes = compiler.compile(args[1]);
			var code = new CodeBlock(vm, null);
			code.load(new BytesInput(bytes.getBytes()));
			return code.exec(0, null, null, [], false, null);
		} catch (e) {
			Sys.println(e.details);
			return "";
		}
	}
}
