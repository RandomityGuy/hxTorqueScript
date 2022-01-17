package console;

enum FunctionType {
	ScriptFunctionType(functionOffset:Int);
	IntCallbackType(callback:(VM, SimObject, Array<String>) -> Int);
	FloatCallbackType(callback:(VM, SimObject, Array<String>) -> Float);
	StringCallbackType(callback:(VM, SimObject, Array<String>) -> String);
	VoidCallbackType(callback:(VM, SimObject, Array<String>) -> Void);

	BoolCallbackType(callback:(VM, SimObject, Array<String>) -> Bool);
}

@:publicFields
class NamespaceEntry {
	var namespace:Namespace;
	var functionName:String;

	var type:FunctionType;

	var minArgs:Int;

	var maxArgs:Int;

	var usage:String;

	var pkg:String;

	public function new(ns:Namespace, fname:String, ftype:FunctionType, minArgs:Int, maxArgs:Int, usage:String, pkg:String) {
		this.namespace = ns;
		this.functionName = fname;
		this.type = ftype;
		this.minArgs = minArgs;
		this.maxArgs = maxArgs;
		this.usage = usage;
		this.pkg = pkg;
	}
}

@:publicFields
class Namespace {
	var name:String;
	var pkg:String;
	var parent:Namespace;

	var entries:Array<NamespaceEntry>;

	public function new(name:String, pkg:String, parent:Namespace) {
		this.name = name;
		this.pkg = pkg;
		this.parent = parent;
		this.entries = new Array<NamespaceEntry>();
	}

	public function addFunction(name:String, functionOffset:Int) {
		var ent = new NamespaceEntry(this, name, FunctionType.ScriptFunctionType(functionOffset), 0, 0, "", null);
		entries.push(ent);
	}

	public function addFunctionFull(name:String, usage:String, minArgs:Int, maxArgs:Int, ftype:FunctionType) {
		var ent = new NamespaceEntry(this, name, ftype, minArgs, maxArgs, usage, null);
		entries.push(ent);
	}

	public function find(functionName:String):NamespaceEntry {
		for (entry in entries) {
			if (entry.functionName.toLowerCase() == functionName.toLowerCase()) {
				return entry;
			}
		}
		if (parent != null)
			return parent.find(functionName);
		return null;
	}
}
