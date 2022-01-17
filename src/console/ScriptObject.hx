package console;

@:publicFields
class ScriptObject extends SimObject {
	var scriptClassName = "ScriptObject";

	var scriptSuperClassName:String = null;

	public function new() {
		super();
	}

	public override function register(vm:VM) {
		if (scriptClassName != "ScriptObject") {
			var parentNamespace = scriptSuperClassName == null ? "ScriptObject" : scriptSuperClassName;
			if (scriptSuperClassName != null)
				vm.linkNamespaces("ScriptObject", parentNamespace);
			vm.linkNamespaces(parentNamespace, scriptClassName);
		}
		super.register(vm);
	}

	public override function getClassName() {
		return scriptClassName;
	}

	public override function assignClassName() {
		return;
	}

	public override function setDataField(field:String, arrayIdx:String, value:String) {
		if (field.toLowerCase() == "class")
			scriptClassName = value;
		else if (field.toLowerCase() == "superclass")
			scriptSuperClassName = value;
		else
			super.setDataField(field, arrayIdx, value);
	}
}
