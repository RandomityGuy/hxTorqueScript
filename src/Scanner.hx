package;

@:expose
class Scanner {
	var source:String;

	var tokens:Array<Token> = [];

	var start = 0;
	var current = 0;
	var line = 1;

	var keywords = [
		'datablock' => TokenType.Datablock, 'package' => TokenType.Package, 'function' => TokenType.Function, 'if' => TokenType.If, 'else' => TokenType.Else,
		'while' => TokenType.While, 'for' => TokenType.For, 'break' => TokenType.Break, 'continue' => TokenType.Continue, 'case' => TokenType.Case,
		'switch' => TokenType.Switch, 'return' => TokenType.Return, 'new' => TokenType.New, 'true' => TokenType.True, 'false' => TokenType.False,
		'default' => TokenType.Default, 'or' => TokenType.Or
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
			case '(':
				addToken(TokenType.LParen);
			case ':':
				addToken(match(':') ? TokenType.DoubleColon : TokenType.Colon);
			case ')':
				addToken(TokenType.RParen);
			case '{':
				addToken(TokenType.LBracket);
			case '}':
				addToken(TokenType.RBracket);
			case ',':
				addToken(TokenType.Comma);
			case '.':
				addToken(TokenType.Dot);
			case ';':
				addToken(TokenType.Semicolon);
			case '[':
				addToken(TokenType.LeftSquareBracket);
			case ']':
				addToken(TokenType.RightSquareBracket);
			case '$':
				addToken(match('=') ? TokenType.StringEquals : TokenType.Dollar);
			case '?':
				addToken(TokenType.QuestionMark);
			case '+':
				addToken(match('=') ? TokenType.PlusAssign : match('+') ? TokenType.PlusPlus : TokenType.Plus);
			case '-':
				addToken(match('=') ? TokenType.MinusAssign : match('-') ? TokenType.MinusMinus : TokenType.Minus);
			case '*':
				addToken(match('=') ? TokenType.MultiplyAssign : TokenType.Multiply);
			case '/':
				if (match('/')) {
					// A comment goes until the end of the line.
					while (peek() != '\n' && !isAtEnd()) {
						advance();
					}
				} else if (match('*')) {
					// A comment goes until "*/".
					while (peek() != '*' || peekNext() != '/') {
						if (isAtEnd()) {
							trace("Unterminated comment.");
						}
						advance();
					}
					advance(); // Consume the "/".
					advance(); // Consume the "*".
				} else
					addToken(match('=') ? TokenType.DivideAssign : TokenType.Divide);
			case '%':
				addToken(match('=') ? TokenType.ModulusAssign : TokenType.Modulus);
			case '@':
				addToken(TokenType.Concat);
			case "&":
				addToken(match('=') ? TokenType.AndAssign : match('&') ? TokenType.LogicalAnd : TokenType.BitwiseAnd);
			case "|":
				addToken(match('=') ? TokenType.OrAssign : match('|') ? TokenType.LogicalOr : TokenType.BitwiseOr);
			case "^":
				addToken(match('=') ? TokenType.XorAssign : TokenType.BitwiseXor);
			case "~":
				addToken(TokenType.Tilde);
			case "!":
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
			case '=':
				addToken(match('=') ? TokenType.Equal : TokenType.Assign);
			case '<':
				addToken(match('=') ? TokenType.LessThanEqual : match('<') ? match('=') ? TokenType.ShiftLeftAssign : TokenType.LeftBitShift : TokenType.LessThan);
			case '>':
				addToken(match('=') ? TokenType.GreaterThanEqual : match('>') ? match('=') ? TokenType.ShiftRightAssign : TokenType.RightBitShift : TokenType.GreaterThan);

			case '"':
				string('"', TokenType.String);

			case '\'':
				string('\'', TokenType.TaggedString);

			case '0':
				if (match('x')) {
					hexNumber();
				} else
					number();

			case '1', '2', '3', '4', '5', '6', '7', '8', '9':
				number();

			case " ", "\r", "\t":
				// Ignore whitespace.
				var a = 1; // Bruh

			case '\n':
				line++;

			default:
				if (isAlpha(c)) {
					identifier();
				} else
					trace('Unexpected character ${line} - ${c}');
		}
	}

	function advance():String {
		return source.charAt(current++);
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

	function peek():String {
		if (isAtEnd())
			return String.fromCharCode(0);
		return source.charAt(current);
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

	function string(delimiter:String, tokenType:TokenType) {
		var doingEscapeSequence = false;

		while (peek() != delimiter && !isAtEnd() || doingEscapeSequence) {
			if (peek() == '\n')
				line++;
			if (!doingEscapeSequence) {
				if (peek() == '\\') {
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
		var escapeMap = [
			"\\t" => "\t", "\\n" => "\n", "\\r" => "\r", "\\\"" => "\"", "\\'" => "'", "\\\\" => "\\", "\\c0" => "\x01", "\\c1" => "\x02", "\\c2" => "\x03",
			"\\c3" => "\x04", "\\c4" => "\x05", "\\c5" => "\x06", "\\c6" => "\x07", "\\c7" => "\x0B", "\\c8" => "\x0C", "\\c9" => "\x0E", "\\cr" => '\x0F',
			"\\cp" => "\x10", "\\co" => "\x11"
		];
		for (o => esc in escapeMap) {
			s = StringTools.replace(s, o, esc);
		}
		if (s.charCodeAt(0) == 0x1) {
			s = "\x02" + s;
		}
		var newStr = s;
		while (newStr.indexOf("\\x") != -1) {
			var hexString = newStr.substring(newStr.indexOf("\\x") + 2, newStr.indexOf("\\x") + 4);
			var intValue = Std.parseInt("0x" + hexString);
			newStr = newStr.substring(0, newStr.indexOf("\\x")) + String.fromCharCode(intValue) + newStr.substring(newStr.indexOf("\\x") + 4);
		}

		return newStr;
	}

	public static function escape(s:String) {
		var escapeMap = [
			"\t" => "\\t", "\n" => "\\n", "\r" => "\\r", "\"" => "\\\"", "'" => "\\'", "\\" => "\\\\", "\x01" => "\\c0", "\x02" => "\\c1", "\x03" => "\\c2",
			"\x04" => "\\c3", "\x05" => "\\c4", "\x06" => "\\c5", "\x07" => "\\c6", "\x0B" => "\\c7", "\x0C" => "\\c8", "\x0E" => "\\c9", "\x0F" => "\\cr",
			"\x10" => "\\cp", "\x11" => "\\co", "\x08" => "\\x08", "\x12" => "\\x12", "\x13" => "\\x13", "\x14" => "\\x14", "\x15" => "\\x15",
			"\x16" => "\\x16", "\x17" => "\\x17", "\x18" => "\\x18", "\x19" => "\\x19", "\x1A" => "\\x1A", "\x1B" => "\\x1B", "\x1C" => "\\x1C",
			"\x1D" => "\\x1D", "\x1E" => "\\x1E", "\x1F" => "\\x1F"
		];
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

	function isDigit(c:String):Bool {
		return "0123456789".indexOf(c) >= 0;
	}

	function isAlpha(c:String):Bool {
		return "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_".indexOf(c) >= 0;
	}

	function isAlphaNumeric(c:String):Bool {
		return isAlpha(c) || isDigit(c);
	}

	function peekNext():String {
		if (current + 1 >= source.length)
			return String.fromCharCode(0);
		return source.charAt(current + 1);
	}

	function hexNumber() {
		while ("0123456789abcdefABCDEF".indexOf(peek()) >= 0)
			advance();

		addToken(TokenType.HexInt, source.substring(start, current));
	}

	function number() {
		while (isDigit(peek()))
			advance();

		var isFloat = false;

		// Look for a fractional part.
		if (peek() == '.' && isDigit(peekNext())) {
			isFloat = true;
			// Consume the "."
			advance();

			while (isDigit(peek()))
				advance();

			if (peek() == 'e' || peek() == 'E') {
				advance();

				if (peek() == '+' || peek() == '-')
					advance();

				while (isDigit(peek()))
					advance();
			}
		}

		// Look for a exponent part.
		if (peek() == 'e' || peek() == 'E') {
			isFloat = true;
			// Consume the "e"
			advance();

			if (peek() == '+' || peek() == '-')
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
