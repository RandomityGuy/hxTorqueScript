package console;

@:publicFields
@:autoBuild(console.ConsoleObjectMacro.build())
@:build(console.ConsoleObjectMacro.build())
class SimObject extends ConsoleObject {
	var name:String;
	var group:SimGroup;

	var id:Int;

	public function new() {
		super();
	}

	public function findObject(name:String):SimObject {
		return null;
	}

	@:consoleMethod(usage = "obj.setName(newName) - Set the global name of the object.", minArgs = 3, maxArgs = 3)
	public static function setName(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		thisObj.name = args[2];
	}

	public function getName():String {
		if (name != null)
			return name;
		else
			return '${id}';
	}

	@:consoleMethod(name = "getName", usage = "obj.getName() - Get the global name of the object.", minArgs = 2, maxArgs = 2)
	public static function getName_method(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return thisObj.getName();
	}

	@:consoleMethod(name = "getClassName", usage = "obj.getClassName() - Get the name of the engine class which the object is an instance of.", minArgs = 2,
		maxArgs = 2)
	public static function getClassName_method(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return thisObj.getClassName();
	}

	@:consoleMethod(usage = "obj.getId() - Get the underlying unique numeric ID of the object.", minArgs = 2, maxArgs = 2)
	public static function getId(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		return thisObj.id;
	}

	@:consoleMethod(usage = "obj.getGroup() - Get the group that this object is contained in.", minArgs = 2, maxArgs = 2)
	public static function getGroup(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		return thisObj.group != null ? thisObj.group.id : -1;
	}

	@:consoleMethod(usage = "obj.delete() - Delete and remove the object.", minArgs = 2, maxArgs = 2)
	public static function delete(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		thisObj.deleteObject();
	}

	@:consoleMethod(usage = "object.schedule(time, command, <arg1...argN>) - Delay an invocation of a method.", minArgs = 4, maxArgs = 0)
	static function schedule(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		var timeDelta = Std.parseInt(args[2]);
		return vm.schedule(timeDelta, thisObj, args.slice(3));
	}

	public function deleteObject() {
		if (vm != null) {
			vm.idMap.remove(this.id);
			if (vm.simObjects.exists(this.name)) {
				if (vm.simObjects.get(this.name) == this) {
					vm.simObjects.remove(this.name);
				}
			}
		}
	}

	public function assignId(id:Int) {
		this.id = id;
	}

	public function assignFieldsFrom(obj:SimObject) {
		for (field in obj.fields) {
			this.fields[field] = obj.fields[field];
		}
	}

	public function processArguments(args:Array<String>) {
		return true;
	}
}
