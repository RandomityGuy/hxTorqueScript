package console;

class SimGroup extends SimSet {
	public function new() {
		super();
	}

	public override function addObject(obj:SimObject) {
		if (obj.group != this) {
			if (obj.group != null) {
				obj.group.removeObject(obj);
			}
			obj.group = this;
			super.addObject(obj);
		}
	}

	public override function removeObject(obj:SimObject) {
		if (obj.group == this) {
			obj.group = null;
			super.removeObject(obj);
		}
	}
}
