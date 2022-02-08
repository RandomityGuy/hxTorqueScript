package;

@:publicFields
class Token {
	var type:TokenType;
	var lexeme:String;
	var literal:Any;
	var line:Int;
	var position:Int;

	public function new(type:TokenType, lexeme:String, literal:Any, line:Int, position:Int) {
		this.type = type;
		this.lexeme = lexeme;
		this.literal = literal;
		this.line = line;
		this.position = position;
	}
}
