package;

class Log {
	static var savedStr = "";

	public static function println(text:String) {
		#if sys
		Sys.println(text);
		#end
		#if js
		js.html.Console.log(savedStr + text);
		#end
		savedStr == "";
	}

	public static function print(text:String) {
		#if sys
		Sys.print(text);
		#end
		savedStr += text;
	}
}
