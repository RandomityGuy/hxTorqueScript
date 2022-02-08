package;

import haxe.Exception;

class SyntaxError extends Exception {
	var token:Token;

	public function new(msg:String, token:Token) {
		super(msg);
		this.token = token;
	}

	override function toString():String {
		var origmsg = super.toString();
		origmsg += ' at line ${this.token.line}, column ${this.token.position}, token: ${this.token.lexeme}';
		return origmsg;
	}
}
