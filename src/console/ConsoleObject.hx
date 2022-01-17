package console;

@:publicFields
class ConsoleObject {
	var className:String = "ConsoleObject";
	var fields:Map<String, String> = [];

	var vm:VM;

	public function new() {
		assignClassName();
	}

	public function register(vm:VM) {
		this.vm = vm;
	}

	public function getDataField(field:String, arrayIdx:String) {
		if (arrayIdx != null) {
			if (this.fields.exists(field + arrayIdx)) {
				return this.fields.get(field + arrayIdx);
			} else
				return "";
		} else {
			if (this.fields.exists(field)) {
				return this.fields.get(field);
			} else
				return "";
		}
	}

	private function assignClassName() {
		className = "ConsoleObject";
	}

	public function setDataField(field:String, arrayIdx:String, value:String) {
		if (arrayIdx != null) {
			this.fields.set(field + arrayIdx, value);
		} else {
			this.fields.set(field, value);
		}
	}

	public function getClassName():String {
		return this.className;
	}
}
