package;

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
				addToken(TokenType.BitwiseXor);
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
				addToken(match('=') ? TokenType.LessThanEqual : match('<') ? TokenType.LeftBitShift : TokenType.LessThan);
			case '>':
				addToken(match('=') ? TokenType.GreaterThanEqual : match('>') ? TokenType.RightBitShift : TokenType.GreaterThan);

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
		tokens.push(new Token(type, text, literal, line));
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
		var value = source.substring(start + 1, current - 1);
		addToken(tokenType, value);
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
