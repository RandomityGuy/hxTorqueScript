package console;

@:build(console.ConsoleFunctionMacro.build())
class ConsoleFunctions {
	@:consoleFunction(usage = "echo(value, ...)", minArgs = 2, maxArgs = 0)
	static function echo(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		trace(args.slice(1).join(""));
	}

	@:consoleFunction(usage = "activatePackage(package)", minArgs = 2, maxArgs = 2)
	static function activatePackage(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		vm.activatePackage(args[1]);
	}

	@:consoleFunction(usage = "deactivatePackage(package)", minArgs = 2, maxArgs = 2)
	static function deactivatePackage(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		vm.deactivatePackage(args[1]);
	}
}
