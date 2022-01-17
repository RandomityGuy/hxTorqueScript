package console;

@:publicFields
class SimDataBlock extends SimObject {
	public function new() {
		super();
	}

	public function preload() {
		return true;
	}

	public override function getClassName() {
		return className;
	}

	public override function assignClassName() {
		return;
	}
}
