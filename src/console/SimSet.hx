package console;

class SimSet extends SimObject {
	var objectList:Array<SimObject> = [];

	public function new() {
		super();
	}

	@:consoleMethod(usage = "set.add(obj1,...)", minArgs = 3, maxArgs = 0)
	public static function add(vm:VM, thisObj:SimSet, args:Array<String>):Void {
		for (i in 2...args.length) {
			var addObj:SimObject = thisObj.vm.findObject(args[i]);
			if (addObj != null)
				thisObj.addObject(addObj);
			else
				trace('Set::add: Object ${args[i]} does not exist.');
		}
	}

	@:consoleMethod(usage = "set.remove(obj1,...)", minArgs = 3, maxArgs = 0)
	public static function remove(vm:VM, thisObj:SimSet, args:Array<String>):Void {
		for (i in 2...args.length) {
			var addObj:SimObject = thisObj.vm.findObject(args[i]);
			if (addObj != null)
				thisObj.removeObject(addObj);
			else
				trace('Set::remove: Object ${args[i]} does not exist.');
		}
	}

	@:consoleMethod(usage = "set.clear()", minArgs = 2, maxArgs = 2)
	public static function clear(vm:VM, thisObj:SimSet, args:Array<String>):Void {
		for (obj in thisObj.objectList)
			thisObj.removeObject(obj);
	}

	@:consoleMethod(usage = "set.getCount()", minArgs = 2, maxArgs = 2)
	public static function getCount(vm:VM, thisObj:SimSet, args:Array<String>):Int {
		return thisObj.objectList.length;
	}

	@:consoleMethod(usage = "set.getObject(objIndex)", minArgs = 3, maxArgs = 3)
	public static function getObject(vm:VM, thisObj:SimSet, args:Array<String>):Int {
		var index = Std.parseInt(args[2]);
		if (index < 0 || index >= thisObj.objectList.length) {
			trace("Set::getObject: index out of range.");
			return -1;
		}
		return thisObj.objectList[index].id;
	}

	@:consoleMethod(usage = "set.isMember(object)", minArgs = 3, maxArgs = 3)
	public static function isMember(vm:VM, thisObj:SimSet, args:Array<String>):Bool {
		var findObj = thisObj.vm.findObject(args[2]);
		if (findObj == null) {
			trace('Set::isMember: ${args[2]} is not an object.');
			return false;
		}
		return thisObj.objectList.contains(findObj);
	}

	@:consoleMethod(usage = "set.bringToFront(object)", minArgs = 3, maxArgs = 3)
	public static function bringToFront(vm:VM, thisObj:SimSet, args:Array<String>):Void {
		var findObj = thisObj.vm.findObject(args[2]);
		if (findObj == null) {
			return;
		}
		thisObj.objectList.remove(findObj);
		thisObj.objectList.insert(0, findObj);
	}

	@:consoleMethod(usage = "set.pushToBack(object)", minArgs = 3, maxArgs = 3)
	public static function pushToBack(vm:VM, thisObj:SimSet, args:Array<String>):Void {
		var findObj = thisObj.vm.findObject(args[2]);
		if (findObj == null) {
			return;
		}
		thisObj.objectList.remove(findObj);
		thisObj.objectList.push(findObj);
	}

	public function addObject(obj:SimObject) {
		if (!objectList.contains(obj))
			objectList.push(obj);
	}

	public function removeObject(obj:SimObject) {
		objectList.remove(obj);
	}

	public override function findObject(name:String):SimObject {
		for (o in objectList) {
			if (o.getName() == name)
				return o;
		}
		return null;
	}
}
