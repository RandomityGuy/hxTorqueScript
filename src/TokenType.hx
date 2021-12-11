package;

enum TokenType {
	BlockComment;
	Datablock;
	Package;
	Function;
	If;
	Else;
	Switch;
	Case;
	Return;
	Break;
	New;
	While;
	For;
	True;
	False;
	Default;
	Plus;
	Minus;
	Multiply;
	Divide;
	Modulus;
	Assign;
	PlusAssign;
	MinusAssign;
	MultiplyAssign;
	OrAssign;
	AndAssign;
	ModulusAssign;
	DivideAssign;
	LessThan;
	GreaterThan;
	LessThanEqual;
	GreaterThanEqual;
	Not;
	NotEqual;
	Equal;
	Tilde;
	StringEquals;
	StringNotEquals;
	Concat;
	SpaceConcat;
	TabConcat;
	NewlineConcat;
	Continue;
	LogicalAnd;
	LogicalOr;
	LeftBitShift;
	RightBitShift;
	BitwiseAnd;
	BitwiseOr;
	BitwiseXor;
	Label;
	Int;
	HexInt;
	Digit;
	HexDigit;
	String;
	TaggedString;
	Exp;
	Float;
	LineComment;
	Ws;
	LParen;
	Colon;
	RParen;
	LBracket;
	RBracket;
	DoubleColon;
	Comma;
	Semicolon;
	LeftSquareBracket;
	RightSquareBracket;
	Or;
	Dollar;
	Dot;
	PlusPlus;
	MinusMinus;
	QuestionMark;
	Eof;
	Unknown;
}
