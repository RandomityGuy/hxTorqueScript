package;

@:expose
class Log {
	static var savedStr = "";

	static dynamic function outputFunction(text:String, newline:Bool) {
		#if sys
		if (newline)
			Sys.println(text);
		else
			Sys.print(text);
		#end
		#if js
		if (newline) {
			js.html.Console.log(savedStr + text);
			savedStr = "";
		} else {
			savedStr += text;
		}
		#end
	}

	public static function println(text:String) {
		outputFunction(text, true);
	}

	public static function print(text:String) {
		outputFunction(text, false);
	}

	public static function setOutputFunction(func:(String, Bool) -> Void) {
		outputFunction = func;
	}
}
