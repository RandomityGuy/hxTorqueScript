package;

@:expose
class Scanner {
	var source:String;

	var tokens:Array<Token> = [];

	var start = 0;
	var current = 0;
	var line = 1;

	var keywords = [
		'datablock' => TokenType.Datablock,
		'package' => TokenType.Package,
		'function' => TokenType.Function,
		'if' => TokenType.If,
		'else' => TokenType.Else,
		'while' => TokenType.While,
		'for' => TokenType.For,
		'break' => TokenType.Break,
		'continue' => TokenType.Continue,
		'case' => TokenType.Case,
		'switch' => TokenType.Switch,
		'return' => TokenType.Return,
		'new' => TokenType.New,
		'true' => TokenType.True,
		'false' => TokenType.False,
		'default' => TokenType.Default,
		'or' => TokenType.Or
	];

	public function new(s:String) {
		source = s;
	}

	public function scanTokens():Array<Token> {
		while (!isAtEnd()) {
			// We are at the beginning of the next lexeme.
			start = current;

			scanToken();
		}

		return tokens;
	}

	function isAtEnd():Bool {
		return current >= source.length;
	}

	function scanToken():Void {
		var c = advance();
		switch (c) {
			case '('.code:
				addToken(TokenType.LParen);
			case ':'.code:
				addToken(match(':') ? TokenType.DoubleColon : TokenType.Colon);
			case ')'.code:
				addToken(TokenType.RParen);
			case '{'.code:
				addToken(TokenType.LBracket);
			case '}'.code:
				addToken(TokenType.RBracket);
			case ','.code:
				addToken(TokenType.Comma);
			case '.'.code:
				addToken(TokenType.Dot);
			case ';'.code:
				addToken(TokenType.Semicolon);
			case '['.code:
				addToken(TokenType.LeftSquareBracket);
			case ']'.code:
				addToken(TokenType.RightSquareBracket);
			case '$'.code:
				addToken(match('=') ? TokenType.StringEquals : TokenType.Dollar);
			case '?'.code:
				addToken(TokenType.QuestionMark);
			case '+'.code:
				addToken(match('=') ? TokenType.PlusAssign : match('+') ? TokenType.PlusPlus : TokenType.Plus);
			case '-'.code:
				addToken(match('=') ? TokenType.MinusAssign : match('-') ? TokenType.MinusMinus : TokenType.Minus);
			case '*'.code:
				addToken(match('=') ? TokenType.MultiplyAssign : TokenType.Multiply);
			case '/'.code:
				if (match('/')) {
					// A comment goes until the end of the line.
					var commentBegin = start;
					while (peek() != '\n'.code && !isAtEnd()) {
						advance();
					}
					addToken(TokenType.Comment(false), source.substring(commentBegin + 2, current));
				} else if (match('*')) {
					// A comment goes until "*/".
					var commentBegin = start;
					while (peek() != '*'.code || peekNext() != '/'.code) {
						if (isAtEnd()) {
							trace("Unterminated comment.");
						}
						advance();
					}
					addToken(TokenType.Comment(true), source.substring(commentBegin + 2, current));
					advance(); // Consume the "/".
					advance(); // Consume the "*".
				} else
					addToken(match('=') ? TokenType.DivideAssign : TokenType.Divide);
			case '%'.code:
				addToken(match('=') ? TokenType.ModulusAssign : TokenType.Modulus);
			case '@'.code:
				addToken(TokenType.Concat);
			case "&".code:
				addToken(match('=') ? TokenType.AndAssign : match('&') ? TokenType.LogicalAnd : TokenType.BitwiseAnd);
			case "|".code:
				addToken(match('=') ? TokenType.OrAssign : match('|') ? TokenType.LogicalOr : TokenType.BitwiseOr);
			case "^".code:
				addToken(match('=') ? TokenType.XorAssign : TokenType.BitwiseXor);
			case "~".code:
				addToken(TokenType.Tilde);
			case "!".code:
				if (match('=')) {
					addToken(TokenType.NotEqual);
				} else if (match('$')) {
					if (match('=')) {
						addToken(TokenType.StringNotEquals);
					} else {
						addToken(TokenType.Not);
						addToken(TokenType.Dollar);
					}
				} else {
					addToken(TokenType.Not);
				}
			case '='.code:
				addToken(match('=') ? TokenType.Equal : TokenType.Assign);
			case '<'.code:
				addToken(match('=') ? TokenType.LessThanEqual : match('<') ? match('=') ? TokenType.ShiftLeftAssign : TokenType.LeftBitShift : TokenType.LessThan);
			case '>'.code:
				addToken(match('=') ? TokenType.GreaterThanEqual : match('>') ? match('=') ? TokenType.ShiftRightAssign : TokenType.RightBitShift : TokenType.GreaterThan);

			case '"'.code:
				string('"'.code, TokenType.String);

			case '\''.code:
				string('\''.code, TokenType.TaggedString);

			case '0'.code:
				if (match('x')) {
					hexNumber();
				} else
					number();

			case x if ('1'.code <= x && x <= '9'.code):
				number();

			case " ".code, "\r".code, "\t".code:
				// Ignore whitespace.
				var a = 1; // Bruh

			case '\n'.code:
				line++;

			default:
				if (isAlpha(c)) {
					identifier();
				} else
					trace('Unexpected character ${line} - ${c}');
		}
	}

	function advance():Int {
		return StringTools.fastCodeAt(source, current++);
	}

	function peekPrev():String {
		if (current == 0)
			return "";
		return source.charAt(current - 1);
	}

	function peekPrev2():String {
		if (current <= 1)
			return "";
		return source.charAt(current - 2);
	}

	function peek():Int {
		if (isAtEnd())
			return 0;
		return StringTools.fastCodeAt(source, current);
	}

	function addToken(type:TokenType, literal:Any = null):Void {
		var text = source.substring(start, current);
		tokens.push(new Token(type, text, literal, line, start));
	}

	function match(expected:String):Bool {
		if (isAtEnd())
			return false;
		if (source.charAt(current) != expected)
			return false;

		current++;
		return true;
	}

	function string(delimiter:Int, tokenType:TokenType) {
		var doingEscapeSequence = false;

		while (peek() != delimiter && !isAtEnd() || doingEscapeSequence) {
			if (peek() == '\n'.code)
				line++;
			if (!doingEscapeSequence) {
				if (peek() == '\\'.code) {
					doingEscapeSequence = true;
				}
			} else {
				doingEscapeSequence = false;
			}
			advance();
		}

		// Unterminated string.
		if (isAtEnd()) {
			trace('Unterminated string');
			return;
		}

		// The closing ".
		advance();

		// Trim the surrounding quotes.
		var value = unescape(source.substring(start + 1, current - 1));
		addToken(tokenType, value);
	}

	public static function unescape(s:String) {
		// var escapeMap = [
		// 	"\\t" => "\t", "\\n" => "\n", "\\r" => "\r", "\\\"" => "\"", "\\'" => "'", "\\\\" => "\\", "\\c0" => "\x01", "\\c1" => "\x02", "\\c2" => "\x03",
		// 	"\\c3" => "\x04", "\\c4" => "\x05", "\\c5" => "\x06", "\\c6" => "\x07", "\\c7" => "\x0B", "\\c8" => "\x0C", "\\c9" => "\x0E", "\\cr" => '\x0F',
		// 	"\\cp" => "\x10", "\\co" => "\x11"
		// ];
		var escapeFrom = [
			"\\t", "\\n", "\\r", "\\\"", "\\'", "\\\\", "\\c0", "\\c1", "\\c2", "\\c3", "\\c4", "\\c5", "\\c6", "\\c7", "\\c8", "\\c9", "\\cr", "\\cp", "\\co"
		];
		var escapeTo = [
			"\t", "\n", "\r", "\"", "'", "\\", "\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x0B", "\x0C", "\x0E", "\x0F", "\x10", "\x11"
		];
		for (i in 0...escapeFrom.length) {
			if (StringTools.contains(s, escapeFrom[i])) {
				s = StringTools.replace(s, escapeFrom[i], escapeTo[i]);
			}
		}
		if (s.charCodeAt(0) == 0x1) {
			s = "\x02" + s;
		}
		var newStr = s;
		while (newStr.indexOf("\\x") != -1) {
			if (newStr.indexOf("\\x") == newStr.length - 2)
				break;
			var hexString = newStr.substring(newStr.indexOf("\\x") + 2, newStr.indexOf("\\x") + 4);
			var intValue = Std.parseInt("0x" + hexString);
			newStr = newStr.substring(0, newStr.indexOf("\\x")) + String.fromCharCode(intValue) + newStr.substring(newStr.indexOf("\\x") + 4);
		}

		return newStr;
	}

	public static function escape(s:String) {
		// var escapeMap = [
		// 	"\t" => "\\t", "\n" => "\\n", "\r" => "\\r", "\"" => "\\\"", "'" => "\\'", "\\" => "\\\\", "\x01" => "\\c0", "\x02" => "\\c1", "\x03" => "\\c2",
		// 	"\x04" => "\\c3", "\x05" => "\\c4", "\x06" => "\\c5", "\x07" => "\\c6", "\x0B" => "\\c7", "\x0C" => "\\c8", "\x0E" => "\\c9", "\x0F" => "\\cr",
		// 	"\x10" => "\\cp", "\x11" => "\\co", "\x08" => "\\x08", "\x12" => "\\x12", "\x13" => "\\x13", "\x14" => "\\x14", "\x15" => "\\x15",
		// 	"\x16" => "\\x16", "\x17" => "\\x17", "\x18" => "\\x18", "\x19" => "\\x19", "\x1A" => "\\x1A", "\x1B" => "\\x1B", "\x1C" => "\\x1C",
		// 	"\x1D" => "\\x1D", "\x1E" => "\\x1E", "\x1F" => "\\x1F"
		// ];
		var escapeFrom = [
			"\\", "'", "\"", "\x1F", "\x1E", "\x1D", "\x1C", "\x1B", "\x1A", "\x19", "\x18", "\x17", "\x16", "\x15", "\x14", "\x13", "\x12", "\x11", "\x10",
			"\x0F", "\x0E", "\r", "\x0C", "\x0B", "\n", "\t", "\x08", "\x07", "\x06", "\x05", "\x04", "\x03", "\x02", "\x01"
		];

		var escapeTo = [
			"\\\\", "\\'", "\\\"", "\\x1F", "\\x1E", "\\x1D", "\\x1C", "\\x1B", "\\x1A", "\\x19", "\\x18", "\\x17", "\\x16", "\\x15", "\\x14", "\\x13",
			"\\x12", "\\co", "\\cp", "\\cr", "\\c9", "\\r", "\\c8", "\\c7", "\\n", "\\t", "\\x08", "\\c6", "\\c5", "\\c4", "\\c3", "\\c2", "\\c1", "\\c0"
		];
		var tagged = false;

		if (s.charCodeAt(0) == 0x02 && s.charCodeAt(1) == 0x01) {
			s = s.substr(1);
			tagged = true;
		}
		for (i in 0...escapeFrom.length) {
			s = StringTools.replace(s, escapeFrom[i], escapeTo[i]);
		}
		if (tagged) {
			s = "\x01" + s.substr(3);
		}
		return s;
	}

	function isDigit(cd:Int):Bool {
		return cd >= "0".code && cd <= "9".code;
	}

	function isAlpha(cd:Int):Bool {
		return ((cd >= "a".code && cd <= "z".code) || (cd >= "A".code && cd <= "Z".code) || cd == "_".code);
	}

	function isAlphaNumeric(c:Int):Bool {
		return isAlpha(c) || isDigit(c);
	}

	function peekNext():Int {
		if (current + 1 >= source.length)
			return 0;
		return StringTools.fastCodeAt(source, current + 1);
	}

	function hexNumber() {
		while (true) {
			var c = peek();
			if ((c >= "0".code && c <= "9".code) || (c >= "a".code && c <= "f".code) || (c >= "A".code && c <= "F".code)) {
				advance();
			} else {
				break;
			}
		}

		addToken(TokenType.HexInt, source.substring(start, current));
	}

	function number() {
		while (isDigit(peek()))
			advance();

		var isFloat = false;

		// Look for a fractional part.
		if (peek() == '.'.code && isDigit(peekNext())) {
			isFloat = true;
			// Consume the "."
			advance();

			while (isDigit(peek()))
				advance();

			if (peek() == 'e'.code || peek() == 'E'.code) {
				advance();

				if (peek() == '+'.code || peek() == '-'.code)
					advance();

				while (isDigit(peek()))
					advance();
			}
		}

		// Look for a exponent part.
		if (peek() == 'e'.code || peek() == 'E'.code) {
			isFloat = true;
			// Consume the "e"
			advance();

			if (peek() == '+'.code || peek() == '-'.code)
				advance();

			while (isDigit(peek()))
				advance();
		}

		if (isFloat)
			addToken(TokenType.Float, source.substring(start, current));
		else
			addToken(TokenType.Int, source.substring(start, current));
	}

	function identifier() {
		while (isAlphaNumeric(peek()))
			advance();

		var text = source.substring(start, current);
		if (this.keywords.exists(text)) {
			addToken(this.keywords.get(text), text);
		} else {
			if (text == "SPC")
				addToken(TokenType.SpaceConcat, text);
			else if (text == "NL")
				addToken(TokenType.NewlineConcat, text);
			else if (text == "TAB")
				addToken(TokenType.TabConcat, text);
			else
				addToken(TokenType.Label, text);
		}
	}
}
