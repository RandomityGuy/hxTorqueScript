package expr;

import Compiler.CompileContext;
import haxe.Exception;

enum TypeReq {
	ReqNone;
	ReqInt;
	ReqFloat;
	ReqString;
}

typedef CaseExpr = {
	conditions:Array<Expr>,
	stmts:Array<Stmt>,
	defaultStmts:Null<Array<Stmt>>,
	next:Null<CaseExpr>
}

@:publicFields
class Stmt {
	static var recursion = 0;

	function precompileStmt(compiler:Compiler, loopCount:Int) {
		return 0;
	}

	function compileStmt(compiler:Compiler, context:Compiler.CompileContext):Int {
		return 0;
	}

	function addBreakCount(compiler:Compiler) {
		if (compiler.inFunction) {
			compiler.breakLineCount++;
		}
	}

	function addBreakLine(ip:Int, compiler:Compiler, context:Compiler.CompileContext) {
		if (compiler.inFunction) {
			var line = compiler.breakLineCount * 2;
			compiler.breakLineCount++;
			if (context.lineBreakPairSize != 0) {
				context.lineBreakPairs[line] = 0;
				context.lineBreakPairs[line + 1] = ip;
			}
		}
	}

	static function precompileBlock(compiler:Compiler, stmts:Array<Stmt>, loopCount:Int) {
		recursion++;
		var ans = stmts.map(x -> x.precompileStmt(compiler, loopCount));
		recursion--;
		var sn = 0;
		for (s in ans) {
			sn += s;
		}
		return sn;
	}

	static function compileBlock(compiler:Compiler, context:Compiler.CompileContext, stmts:Array<Stmt>) {
		recursion++;
		for (s in stmts) {
			context.ip = s.compileStmt(compiler, context);
		}
		recursion--;
		return context.ip;
	}
}

@:publicFields
class BreakStmt extends Stmt {
	public function new() {}

	public override function precompileStmt(compiler:Compiler, loopCount:Int):Int {
		// JMP
		// <breakpoint>
		if (loopCount > 0) {
			this.addBreakCount(compiler);
			return 2;
		}
		trace("Warning: break outside of loop.");
		return 0;
	}

	public override function compileStmt(compiler:Compiler, context:CompileContext) {
		if (context.breakPoint > 0) {
			this.addBreakLine(context.ip, compiler, context);
			context.codeStream[context.ip++] = cast OpCode.Jmp;
			context.codeStream[context.ip++] = context.breakPoint;
		}
		return context.ip;
	}
}

@:publicFields
class ContinueStmt extends Stmt {
	public function new() {}

	public override function precompileStmt(compiler:Compiler, loopCount:Int):Int {
		// JMP
		// <continuePoint>
		if (loopCount > 0) {
			this.addBreakCount(compiler);
			return 2;
		}
		trace("Warning: continue outside of loop.");
		return 0;
	}

	public override function compileStmt(compiler:Compiler, context:CompileContext) {
		if (context.continuePoint > 0) {
			this.addBreakLine(context.ip, compiler, context);
			context.codeStream[context.ip++] = cast OpCode.Jmp;
			context.codeStream[context.ip++] = context.continuePoint;
		}
		return context.ip;
	}
}

@:publicFields
class Expr extends Stmt {
	public function new() {}

	public override function precompileStmt(compiler:Compiler, loopCount:Int):Int {
		this.addBreakCount(compiler);
		return precompile(compiler, ReqNone);
	}

	public override function compileStmt(compiler:Compiler, context:CompileContext):Int {
		this.addBreakLine(context.ip, compiler, context);
		return compile(compiler, context, ReqNone);
	}

	public function precompile(compiler:Compiler, typeReq:TypeReq) {
		return 0;
	}

	public function compile(compiler:Compiler, context:Compiler.CompileContext, typeReq:TypeReq) {
		return 0;
	}

	public function getPrefferredType() {
		return ReqNone;
	}

	public static function conversionOp(src:TypeReq, dest:TypeReq):OpCode {
		return switch (src) {
			case ReqString:
				switch (dest) {
					case ReqInt:
						return OpCode.StrToUInt;
					case ReqFloat:
						return OpCode.StrToFlt;
					case ReqNone:
						return OpCode.StrToNone;
					default:
						return OpCode.Invalid;
				}

			case ReqFloat:
				switch (dest) {
					case ReqInt:
						return OpCode.FltToUInt;
					case ReqString:
						return OpCode.FltToStr;
					case ReqNone:
						return OpCode.FltToNone;
					default:
						return OpCode.Invalid;
				}

			case ReqInt:
				switch (dest) {
					case ReqString:
						return OpCode.UIntToStr;
					case ReqFloat:
						return OpCode.UIntToFlt;
					case ReqNone:
						return OpCode.UIntToNone;
					default:
						return OpCode.Invalid;
				}

			default:
				return OpCode.Invalid;
		}
	}
}

@:publicFields
class ReturnStmt extends Stmt {
	var expr:Null<Expr>;

	public function new(expr:Null<Expr>) {
		this.expr = expr;
	}

	public override function precompileStmt(compiler:Compiler, loopCount:Int):Int {
		// Return
		// <expr>?

		this.addBreakCount(compiler);
		if (expr == null)
			return 1;
		else
			return 1 + expr.precompile(compiler, ReqString);
	}

	public override function compileStmt(compiler:Compiler, context:CompileContext):Int {
		this.addBreakLine(context.ip, compiler, context);
		if (expr == null)
			context.codeStream[context.ip++] = cast OpCode.Return;
		else {
			context.ip = expr.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.Return;
		}
		return context.ip;
	}
}

@:publicFields
class IfStmt extends Stmt {
	var condition:Expr;
	var body:Array<Stmt>;
	var elseBlock:Null<Array<Stmt>>;

	var integer:Bool;

	var endifOffset:Int;
	var elseOffset:Int;

	public function new(condition:Expr, body:Array<Stmt>, elseBlock:Array<Stmt>) {
		this.condition = condition;
		this.body = body;
		this.elseBlock = elseBlock;
	}

	public override function precompileStmt(compiler:Compiler, loopCount:Int):Int {
		// <condition>
		// integer ? JmpIfNot : JmpIffNot
		// <offset> = elseBlock != null ? start + elseOffset : start + endifOffset
		// <body>
		// [if elseBlock != null:
		// JMP
		// start + endifOffset
		// elseBlock]

		var exprSize = 0;
		this.addBreakCount(compiler);

		if (condition.getPrefferredType() == ReqInt) {
			exprSize += condition.precompile(compiler, ReqInt);
			integer = true;
		} else {
			exprSize += condition.precompile(compiler, ReqFloat);
			integer = false;
		}

		var ifSize = Stmt.precompileBlock(compiler, body, loopCount);
		if (elseBlock == null) {
			endifOffset = exprSize + 2 + ifSize;
		} else {
			elseOffset = exprSize + 2 + ifSize + 2;
			var elseSize = Stmt.precompileBlock(compiler, elseBlock, loopCount);
			endifOffset = elseOffset + elseSize;
		}
		return endifOffset;
	}

	public override function compileStmt(compiler:Compiler, context:CompileContext):Int {
		var start = context.ip;
		this.addBreakLine(start, compiler, context);

		context.ip = condition.compile(compiler, context, integer ? ReqInt : ReqFloat);
		context.codeStream[context.ip++] = integer ? cast OpCode.JmpIfNot : cast OpCode.JmpIffNot;

		if (elseBlock != null) {
			context.codeStream[context.ip++] = start + elseOffset;
			context.ip = Stmt.compileBlock(compiler, context, body);
			context.codeStream[context.ip++] = cast OpCode.Jmp;
			context.codeStream[context.ip++] = start + endifOffset;
			context.ip = Stmt.compileBlock(compiler, context, elseBlock);
		} else {
			context.codeStream[context.ip++] = start + endifOffset;
			context.ip = Stmt.compileBlock(compiler, context, body);
		}
		return context.ip;
	}
}

@:publicFields
class LoopStmt extends Stmt {
	var condition:Expr;
	var init:Null<Expr>;
	var end:Null<Expr>;
	var body:Array<Stmt>;

	var integer:Bool;
	var loopBlockStartOffset:Int;
	var continueOffset:Int;
	var breakOffset:Int;

	public function new(condition:Expr, init:Expr, end:Expr, body:Array<Stmt>) {
		this.condition = condition;
		this.init = init;
		this.end = end;
		this.body = body;
	}

	public override function precompileStmt(compiler:Compiler, loopCount:Int):Int {
		// <init>?
		// <condition>
		// integer ? JmpIfNot : JmpIffNot
		// start + breakOffset
		// <body>
		// <end>?
		// <condition>
		// integer ? JmpIf : JmpIff
		// start + loopBlockStartOffset
		var initSize = 0;
		this.addBreakCount(compiler);
		if (init != null)
			initSize = init.precompile(compiler, ReqNone);
		var testSize = 0;
		if (condition.getPrefferredType() == ReqInt) {
			integer = true;
			testSize = condition.precompile(compiler, ReqInt);
		} else {
			integer = false;
			testSize = condition.precompile(compiler, ReqFloat);
		}
		var blockSize = Stmt.precompileBlock(compiler, body, loopCount + 1);
		var endLoopSize = 0;
		if (end != null)
			endLoopSize = end.precompile(compiler, ReqNone);

		loopBlockStartOffset = initSize + testSize + 2;
		continueOffset = loopBlockStartOffset + blockSize;
		breakOffset = continueOffset + endLoopSize + testSize + 2;
		return breakOffset;
	}

	public override function compileStmt(compiler:Compiler, context:CompileContext):Int {
		this.addBreakLine(context.ip, compiler, context);
		var start = context.ip;
		if (init != null)
			context.ip = init.compile(compiler, context, ReqNone);

		context.ip = condition.compile(compiler, context, integer ? ReqInt : ReqFloat);
		context.codeStream[context.ip++] = integer ? cast OpCode.JmpIfNot : cast OpCode.JmpIffNot;
		context.codeStream[context.ip++] = start + breakOffset;

		var cbreak = context.breakPoint;
		var ccontinue = context.continuePoint;

		context.breakPoint = start + breakOffset;
		context.continuePoint = start + continueOffset;

		context.ip = Stmt.compileBlock(compiler, context, body);

		context.breakPoint = cbreak;
		context.continuePoint = ccontinue;

		if (end != null)
			context.ip = end.compile(compiler, context, ReqNone);
		context.ip = condition.compile(compiler, context, integer ? ReqInt : ReqFloat);

		context.codeStream[context.ip++] = integer ? cast OpCode.JmpIf : cast OpCode.JmpIff;
		context.codeStream[context.ip++] = start + loopBlockStartOffset;
		return context.ip;
	}
}

@:publicFields
class BinaryExpr extends Expr {
	var left:Expr;
	var right:Expr;
	var op:Token;
}

@:publicFields
class FloatBinaryExpr extends BinaryExpr {
	public function new(left:Expr, right:Expr, op:Token) {
		super();
		this.left = left;
		this.right = right;
		this.op = op;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// <left>
		// <right>
		// <operand>
		// <convertOp>?
		var addSize = left.precompile(compiler, ReqFloat) + right.precompile(compiler, ReqFloat) + 1;
		if (typeReq != ReqFloat) {
			addSize++;
		}

		return addSize;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = right.compile(compiler, context, ReqFloat);
		context.ip = left.compile(compiler, context, ReqFloat);
		var operand = switch (op.type) {
			case Plus:
				OpCode.Add;

			case Minus:
				OpCode.Sub;

			case Divide:
				OpCode.Div;

			case Multiply:
				OpCode.Mul;

			default:
				OpCode.Invalid;
		}

		context.codeStream[context.ip++] = cast operand;

		if (typeReq != ReqFloat)
			context.codeStream[context.ip++] = cast Expr.conversionOp(ReqFloat, typeReq);

		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqFloat;
	}
}

@:publicFields
class IntBinaryExpr extends BinaryExpr {
	var subType:TypeReq;
	var operand:OpCode;

	public function new(left:Expr, right:Expr, op:Token) {
		super();
		this.left = left;
		this.right = right;
		this.op = op;
	}

	function getSubTypeOperand() {
		subType = ReqInt;

		var opmap = [
			TokenType.BitwiseXor => OpCode.Xor, TokenType.Modulus => OpCode.Mod, TokenType.BitwiseAnd => OpCode.BitAnd, TokenType.BitwiseOr => OpCode.BitOr,
			TokenType.LessThan => OpCode.CmpLT, TokenType.LessThanEqual => OpCode.CmpLE, TokenType.GreaterThan => OpCode.CmpGT,
			TokenType.GreaterThanEqual => OpCode.CmpGE, TokenType.Equal => OpCode.CmpEQ, TokenType.NotEqual => OpCode.CmpNE, TokenType.LogicalOr => OpCode.Or,
			TokenType.LogicalAnd => OpCode.And, TokenType.RightBitShift => OpCode.Shr, TokenType.LeftBitShift => OpCode.Shl,
		];

		var fltops = [
			TokenType.LessThan,
			TokenType.LessThanEqual,
			TokenType.GreaterThan,
			TokenType.GreaterThanEqual,
			TokenType.Equal,
			TokenType.NotEqual
		];

		this.operand = opmap.get(op.type);

		if (fltops.contains(op.type))
			subType = ReqFloat;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		getSubTypeOperand();
		// Verified to be correct

		var addSize = left.precompile(compiler, subType) + right.precompile(compiler, subType) + 1;

		if (operand == OpCode.Or || operand == OpCode.And) {
			addSize++;
		}

		if (typeReq != ReqInt)
			addSize++;

		return addSize;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		if (operand == OpCode.Or || operand == OpCode.And) {
			context.ip = left.compile(compiler, context, subType);
			context.codeStream[context.ip++] = operand == OpCode.Or ? cast OpCode.JmpIfNP : cast OpCode.JmpIfNotNP;
			var jmpIp = context.ip++;
			context.ip = right.compile(compiler, context, subType);
			context.codeStream[jmpIp] = context.ip;
		} else {
			context.ip = right.compile(compiler, context, subType);
			context.ip = left.compile(compiler, context, subType);
			context.codeStream[context.ip++] = cast operand;
		}

		if (typeReq != ReqInt)
			context.codeStream[context.ip++] = cast Expr.conversionOp(ReqInt, typeReq);

		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqInt;
	}
}

@:publicFields
class StrEqExpr extends BinaryExpr {
	public function new(left:Expr, right:Expr, op:Token) {
		super();
		this.left = left;
		this.right = right;
		this.op = op;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// <left>
		// AdvanceStrNul
		// <right>
		// CompareStr
		// Not?
		// <conversionOp>
		var size = left.precompile(compiler, ReqString) + right.precompile(compiler, ReqString) + 2;

		if (op.type == TokenType.StringNotEquals)
			size++;

		if (typeReq != ReqInt)
			size++;

		return size;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = left.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.AdvanceStrNul;
		context.ip = right.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.CompareStr;

		if (op.type == TokenType.StringNotEquals)
			context.codeStream[context.ip++] = cast OpCode.Not;

		if (typeReq != ReqInt)
			context.codeStream[context.ip++] = cast Expr.conversionOp(ReqInt, typeReq);

		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqInt;
	}
}

@:publicFields
class StrCatExpr extends BinaryExpr {
	public function new(left:Expr, right:Expr, op:Token) {
		super();
		this.left = left;
		this.right = right;
		this.op = op;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// <left>
		// AdvanceStr | AdvanceStrAppendChar
		// <appendChar>?
		// <right>
		// RewindStr
		// (StrToUInt | StrToFlt)?
		var addSize = left.precompile(compiler, ReqString) + right.precompile(compiler, ReqString) + 2;

		if (op.type != TokenType.Concat)
			addSize++;

		if (typeReq != ReqString)
			addSize++;

		return addSize;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = left.compile(compiler, context, ReqString);
		if (op.type == TokenType.Concat)
			context.codeStream[context.ip++] = cast OpCode.AdvanceStr;
		else {
			context.codeStream[context.ip++] = cast OpCode.AdvanceStrAppendChar;
			context.codeStream[context.ip++] = cast switch (op.type) {
				case SpaceConcat:
					32;
				case TabConcat:
					9;
				case NewlineConcat:
					10;

				default:
					0;
			};
		}
		context.ip = right.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.RewindStr;
		switch (typeReq) {
			case ReqInt:
				context.codeStream[context.ip++] = cast OpCode.StrToUInt;

			case ReqFloat:
				context.codeStream[context.ip++] = cast OpCode.StrToFlt;

			default:
				false;
		}
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqString;
	}
}

@:publicFields
class CommaCatExpr extends BinaryExpr {
	public function new(left:Expr, right:Expr) {
		super();
		this.left = left;
		this.right = right;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// <left>
		// AdvanceStrComma
		// <right>
		// RewindStr
		// (StrToUInt | StrToFlt)?
		var addSize = left.precompile(compiler, ReqString) + right.precompile(compiler, ReqString) + 2;

		if (typeReq != ReqString)
			addSize++;

		return addSize;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = left.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.AdvanceStrComma;
		context.ip = right.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.RewindStr;
		if (typeReq == ReqInt || typeReq == ReqFloat)
			trace("Warning: Converting comma string to number");

		if (typeReq == ReqInt)
			context.codeStream[context.ip++] = cast OpCode.StrToUInt;
		else if (typeReq == ReqFloat)
			context.codeStream[context.ip++] = cast OpCode.StrToFlt;

		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqString;
	}
}

@:publicFields
class ConditionalExpr extends Expr {
	var condition:Expr;
	var trueExpr:Expr;
	var falseExpr:Expr;

	var integer:Bool;

	public function new(condition:Expr, trueExpr:Expr, falseExpr:Expr) {
		super();
		this.condition = condition;
		this.trueExpr = trueExpr;
		this.falseExpr = falseExpr;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// <condition>
		// integer ? JmpIfNot : JmpIffNot
		// jmpElseIp
		// <trueExpr>
		// Jmp
		// jmpEndIp
		// <falseExpr>
		// jmpEndIp
		var exprSize = 0;

		if (condition.getPrefferredType() == ReqInt) {
			exprSize = condition.precompile(compiler, ReqInt);
			integer = true;
		} else {
			exprSize = condition.precompile(compiler, ReqFloat);
			integer = false;
		}

		return exprSize + trueExpr.precompile(compiler, typeReq) + falseExpr.precompile(compiler, typeReq) + 4;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = condition.compile(compiler, context, integer ? ReqInt : ReqFloat);
		context.codeStream[context.ip++] = integer ? cast OpCode.JmpIfNot : cast OpCode.JmpIffNot;
		var jumpElseIp = context.ip++;
		context.ip = trueExpr.compile(compiler, context, typeReq);
		context.codeStream[context.ip++] = cast OpCode.Jmp;
		var jumpEndIp = context.ip++;
		context.codeStream[jumpElseIp] = cast context.ip;
		context.ip = falseExpr.compile(compiler, context, typeReq);
		context.codeStream[jumpEndIp] = cast context.ip;
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return trueExpr.getPrefferredType();
	}
}

@:publicFields
class IntUnaryExpr extends Expr {
	var expr:Expr;
	var op:Token;

	var integer:Bool;

	public function new(expr:Expr, op:Token) {
		super();
		this.expr = expr;
		this.op = op;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// <expr>
		// Not | NotF | OnesComplement
		// <conversionOp>?
		integer = true;
		var prefType = expr.getPrefferredType();
		if (this.op.type == TokenType.Not && prefType == ReqFloat || prefType == ReqString) {
			integer = false;
		}

		var exprSize = expr.precompile(compiler, integer ? ReqInt : ReqFloat);

		if (typeReq != ReqInt)
			return exprSize + 2;
		else
			return exprSize + 1;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = expr.compile(compiler, context, integer ? ReqInt : ReqFloat);
		if (op.type == Not) {
			context.codeStream[context.ip++] = integer ? cast OpCode.Not : cast OpCode.NotF;
		} else if (op.type == Tilde)
			context.codeStream[context.ip++] = cast OpCode.OnesComplement;
		if (typeReq != ReqInt)
			context.codeStream[context.ip++] = cast Expr.conversionOp(ReqInt, typeReq);
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqInt;
	}
}

@:publicFields
class FloatUnaryExpr extends Expr {
	var expr:Expr;
	var op:Token;

	public function new(expr:Expr, op:Token) {
		super();
		this.expr = expr;
		this.op = op;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// <expr>
		// Neg
		// <conversionOp>?
		var exprSize = expr.precompile(compiler, TypeReq.ReqFloat);
		if (typeReq != ReqFloat)
			return exprSize + 2;
		else
			return exprSize + 1;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = expr.compile(compiler, context, TypeReq.ReqFloat);
		context.codeStream[context.ip++] = cast OpCode.Neg;
		if (typeReq != ReqFloat)
			context.codeStream[context.ip++] = cast Expr.conversionOp(ReqFloat, typeReq);

		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqFloat;
	}
}

enum VarType {
	Global;
	Local;
}

@:publicFields
class VarExpr extends Expr {
	var name:Token;
	var arrayIndex:Null<Expr>;

	var type:VarType;

	function new(name:Token, arrayIndex:Null<Expr>, type:VarType) {
		super();
		this.name = name;
		this.arrayIndex = arrayIndex;
		this.type = type;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// arrayIndex != null ? LoadImmedIdent : SetCurVar
		// name
		// [ AdvanceStr
		//   <arrayIndex>
		//   RewindStr
		//   SetCurVarArray ]?
		// LoadVarUint | LoadVarFlt | LoadVarStr
		if (typeReq == ReqNone)
			return 0;

		compiler.precompileIdent((type == Global ? "$" : "%") + name.literal);

		if (arrayIndex != null)
			return arrayIndex.precompile(compiler, ReqString) + 6;
		else
			return 3;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		if (typeReq == ReqNone)
			return 0;

		context.codeStream[context.ip++] = arrayIndex != null ? cast OpCode.LoadImmedIdent : cast OpCode.SetCurVar;
		context.codeStream[context.ip] = compiler.compileIdent((type == Global ? "$" : "%") + name.literal, context.ip);
		context.ip++;

		if (arrayIndex != null) {
			context.codeStream[context.ip++] = cast OpCode.AdvanceStr;
			context.ip = arrayIndex.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.RewindStr;
			context.codeStream[context.ip++] = cast OpCode.SetCurVarArray;
		}

		switch (typeReq) {
			case ReqInt:
				context.codeStream[context.ip++] = cast OpCode.LoadVarUInt;

			case ReqFloat:
				context.codeStream[context.ip++] = cast OpCode.LoadVarFlt;

			case ReqString:
				context.codeStream[context.ip++] = cast OpCode.LoadVarStr;

			default:
				false;
		}

		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqNone;
	}
}

@:publicFields
class IntExpr extends Expr {
	var value:Int;

	var index:Int;

	public function new(value:Int) {
		super();
		this.value = value;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// LoadImmedUint | LoadImmedStr | LoadImmedFlt
		// index
		if (typeReq == ReqNone)
			return 0;
		if (typeReq == ReqString)
			index = compiler.addIntString(value);
		else if (typeReq == ReqFloat)
			index = compiler.addFloat(value);
		return 2;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		switch (typeReq) {
			case ReqInt:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedUInt;
				context.codeStream[context.ip++] = value;

			case ReqString:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedStr;
				context.codeStream[context.ip++] = index;

			case ReqFloat:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedFlt;
				context.codeStream[context.ip++] = index;

			default:
				false;
		}
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqInt;
	}
}

@:publicFields
class FloatExpr extends Expr {
	var value:Float;

	var index:Int;

	public function new(value:Float) {
		super();
		this.value = value;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// LoadImmedUint | LoadImmedStr | LoadImmedFlt
		// index
		if (typeReq == ReqNone)
			return 0;
		if (typeReq == ReqString)
			index = compiler.addFloatString(value);
		else if (typeReq == ReqFloat)
			index = compiler.addFloat(value);
		return 2;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		switch (typeReq) {
			case ReqInt:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedUInt;
				context.codeStream[context.ip++] = cast value;

			case ReqString:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedStr;
				context.codeStream[context.ip++] = index;

			case ReqFloat:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedFlt;
				context.codeStream[context.ip++] = index;

			default:
				false;
		}
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqFloat;
	}
}

@:publicFields
class StringConstExpr extends Expr {
	var value:String;
	var tag:Bool;

	var fVal:Float;
	var index:Int;

	public function new(value:String, tag:Bool) {
		super();
		this.value = value;
		this.tag = tag;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// LoadImmedUint | LoadImmedStr | LoadImmedFlt | TagToStr
		// index
		if (typeReq == ReqString) {
			index = compiler.addString(value, true, tag);
			return 2;
		} else if (typeReq == ReqNone)
			return 0;

		fVal = compiler.stringToNumber(value);

		if (typeReq == ReqFloat)
			index = compiler.addFloat(fVal);

		return 2;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		switch (typeReq) {
			case ReqInt:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedUInt;
				context.codeStream[context.ip++] = cast fVal;

			case ReqString:
				context.codeStream[context.ip++] = tag ? cast OpCode.TagToStr : cast OpCode.LoadImmedStr;
				context.codeStream[context.ip++] = index;

			case ReqFloat:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedFlt;
				context.codeStream[context.ip++] = index;

			default:
				false;
		}
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqString;
	}
}

@:publicFields
class ConstantExpr extends Expr {
	var name:Token;

	var fVal:Float;
	var index:Int;

	public function new(name:Token) {
		super();
		this.name = name;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// LoadImmedUint | LoadImmedIdent | LoadImmedFlt
		// data
		if (typeReq == ReqString) {
			compiler.precompileIdent(name.literal);
			return 2;
		} else if (typeReq == ReqNone)
			return 0;

		fVal = compiler.stringToNumber(name.literal);

		if (typeReq == ReqFloat)
			index = compiler.addFloat(fVal);

		return 2;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		switch (typeReq) {
			case ReqInt:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedUInt;
				context.codeStream[context.ip++] = cast fVal;

			case ReqString:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedIdent;
				context.codeStream[context.ip] = compiler.compileIdent(name.literal, context.ip);
				context.ip++;

			case ReqFloat:
				context.codeStream[context.ip++] = cast OpCode.LoadImmedFlt;
				context.codeStream[context.ip++] = index;

			default:
				false;
		}
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqString;
	}
}

@:publicFields
class AssignExpr extends Expr {
	var varExpr:VarExpr;
	var expr:Expr;

	var subType:TypeReq;

	public function new(varExpr:VarExpr, expr:Expr) {
		super();
		this.varExpr = varExpr;
		this.expr = expr;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// Verified to be correct
		subType = expr.getPrefferredType();

		if (subType == ReqNone)
			subType = typeReq;

		if (subType == ReqNone)
			subType = ReqString;

		var addSize = 0;
		if (typeReq != subType)
			addSize = 1;

		var retSize = expr.precompile(compiler, subType);

		compiler.precompileIdent((varExpr.type == Global ? "$" : "%") + varExpr.name.literal);

		if (varExpr.arrayIndex != null) {
			if (subType == ReqString)
				return varExpr.arrayIndex.precompile(compiler, ReqString) + retSize + addSize + 8;
			else
				return varExpr.arrayIndex.precompile(compiler, ReqString) + retSize + addSize + 6;
		} else
			return retSize + addSize + 3;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = expr.compile(compiler, context, subType);
		if (varExpr.arrayIndex != null) {
			if (subType == ReqString)
				context.codeStream[context.ip++] = cast OpCode.AdvanceStr;

			context.codeStream[context.ip++] = cast OpCode.LoadImmedIdent;
			context.codeStream[context.ip] = compiler.compileIdent((varExpr.type == Global ? "$" : "%") + varExpr.name.literal, context.ip);

			context.ip++;
			context.codeStream[context.ip++] = cast OpCode.AdvanceStr;
			context.ip = varExpr.arrayIndex.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.RewindStr;
			context.codeStream[context.ip++] = cast OpCode.SetCurVarArrayCreate;
			if (subType == ReqString)
				context.codeStream[context.ip++] = cast OpCode.TerminateRewindStr;
		} else {
			context.codeStream[context.ip++] = cast OpCode.SetCurVarCreate;
			context.codeStream[context.ip] = compiler.compileIdent((varExpr.type == Global ? "$" : "%") + varExpr.name.literal, context.ip);
			context.ip++;
		}

		switch (subType) {
			case ReqString:
				context.codeStream[context.ip++] = cast OpCode.SaveVarStr;

			case ReqInt:
				context.codeStream[context.ip++] = cast OpCode.SaveVarUInt;

			case ReqFloat:
				context.codeStream[context.ip++] = cast OpCode.SaveVarFlt;

			default:
				false;
		}

		if (typeReq != subType)
			context.codeStream[context.ip++] = cast Expr.conversionOp(subType, typeReq);

		return context.ip++;
	}

	public override function getPrefferredType():TypeReq {
		return expr.getPrefferredType();
	}
}

@:publicFields
class AssignOpExpr extends Expr {
	var varExpr:VarExpr;
	var expr:Expr;
	var op:Token;

	var subType:TypeReq;
	var operand:OpCode;

	function getAssignOpTypeOp() {
		switch (op.type) {
			case PlusAssign:
				subType = ReqFloat;
				operand = Add;

			case MinusAssign:
				subType = ReqFloat;
				operand = Sub;

			case MultiplyAssign:
				subType = ReqFloat;
				operand = Mul;

			case DivideAssign:
				subType = ReqFloat;
				operand = Div;

			case ModulusAssign:
				subType = ReqInt;
				operand = Mod;

			case AndAssign:
				subType = ReqInt;
				operand = BitAnd;

			case XorAssign:
				subType = ReqInt;
				operand = Xor;

			case OrAssign:
				subType = ReqInt;
				operand = BitOr;

			case ShiftLeftAssign:
				subType = ReqInt;
				operand = Shl;

			case ShiftRightAssign:
				subType = ReqInt;
				operand = Shr;

			case PlusPlus:
				subType = ReqFloat;
				operand = Add;
				expr = new IntExpr(1);

			case MinusMinus:
				subType = ReqFloat;
				operand = Sub;
				expr = new IntExpr(1);

			default:
				throw new Exception("Unknown assignment expression");
		}
	}

	public function new(varExpr:VarExpr, expr:Expr, op:Token) {
		super();
		this.varExpr = varExpr;
		this.expr = expr;
		this.op = op;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// Verified to be correct
		this.getAssignOpTypeOp();

		compiler.precompileIdent((varExpr.type == Global ? "$" : "%") + varExpr.name.literal);

		var size = expr.precompile(compiler, subType);

		if (typeReq != subType)
			size++;

		if (this.varExpr.arrayIndex == null)
			return size + 5;
		else {
			size += this.varExpr.arrayIndex.precompile(compiler, ReqString);
			return size + 8;
		}
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = expr.compile(compiler, context, subType);
		if (this.varExpr.arrayIndex == null) {
			context.codeStream[context.ip++] = cast OpCode.SetCurVarCreate;
			context.codeStream[context.ip] = compiler.compileIdent((varExpr.type == Global ? "$" : "%") + varExpr.name.literal, context.ip);
			context.ip++;
		} else {
			context.codeStream[context.ip++] = cast OpCode.LoadImmedIdent;
			context.codeStream[context.ip] = compiler.compileIdent((varExpr.type == Global ? "$" : "%") + varExpr.name.literal, context.ip);
			context.ip++;
			context.codeStream[context.ip++] = cast OpCode.AdvanceStr;
			context.ip = varExpr.arrayIndex.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.RewindStr;
			context.codeStream[context.ip++] = cast OpCode.SetCurVarArrayCreate;
		}
		context.codeStream[context.ip++] = (subType == ReqFloat) ? cast OpCode.LoadVarFlt : cast OpCode.LoadVarUInt;
		context.codeStream[context.ip++] = cast operand;
		context.codeStream[context.ip++] = (subType == ReqFloat) ? cast OpCode.SaveVarFlt : cast OpCode.SaveVarUInt;
		if (typeReq != subType)
			context.codeStream[context.ip++] = cast Expr.conversionOp(subType, typeReq);
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		this.getAssignOpTypeOp();
		return subType;
	}
}

enum abstract FuncCallType(Int) {
	var FunctionCall;
	var MethodCall;
	var ParentCall;
}

@:publicFields
class FuncCallExpr extends Expr {
	var name:Token;
	var namespace:Token;
	var args:Array<Expr>;
	var callType:FuncCallType;

	public function new(name:Token, namespace:Token, args:Array<Expr>, callType:FuncCallType) {
		super();
		this.name = name;
		this.namespace = namespace;
		this.args = args;
		this.callType = callType;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// Verified to be correct
		var size = 0;
		if (typeReq != ReqString)
			size++;

		compiler.precompileIdent(name.literal);
		compiler.precompileIdent(namespace != null ? namespace.literal : "");

		for (i in 0...args.length) {
			size += args[i].precompile(compiler, ReqString) + 1;
		}

		return size + 5;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.codeStream[context.ip++] = cast OpCode.PushFrame;
		for (expr in args) {
			context.ip = expr.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.Push;
		}
		if (callType == MethodCall || callType == ParentCall)
			context.codeStream[context.ip++] = cast OpCode.CallFunc;
		else
			context.codeStream[context.ip++] = cast OpCode.CallFuncResolve;

		context.codeStream[context.ip] = compiler.compileIdent(name.literal, context.ip);
		context.ip++;
		context.codeStream[context.ip] = compiler.compileIdent(namespace != null ? namespace.literal : null, context.ip);
		context.ip++;
		context.codeStream[context.ip++] = cast callType;
		if (typeReq != ReqString)
			context.codeStream[context.ip++] = cast Expr.conversionOp(ReqString, typeReq);
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqString;
	}
}

@:publicFields
class SlotAccessExpr extends Expr {
	var objectExpr:Expr;
	var arrayExpr:Expr;
	var slotName:Token;

	public function new(objectExpr:Expr, arrayExpr:Expr, slotName:Token) {
		super();
		this.objectExpr = objectExpr;
		this.arrayExpr = arrayExpr;
		this.slotName = slotName;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		// [
		//   <arrayExpr>
		//   AdvanceStr
		// ]?
		// <objectExpr>
		// SetCurObject
		// SetCurField
		// slotName
		// [
		//   TerminateRewindStr
		//   SetCurFieldArray
		// ]?
		// LoadFieldUInt | LoadFieldFlt | LoadFieldStr
		if (typeReq == ReqNone)
			return 0;
		var size = 0;
		compiler.precompileIdent(slotName.literal);
		if (arrayExpr != null) {
			size += 3 + arrayExpr.precompile(compiler, ReqString);
		}

		size += objectExpr.precompile(compiler, ReqString) + 3;

		return size + 1;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		if (typeReq == ReqNone)
			return context.ip;

		if (arrayExpr != null) {
			context.ip = arrayExpr.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.AdvanceStr;
		}
		context.ip = objectExpr.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.SetCurObject;
		context.codeStream[context.ip++] = cast OpCode.SetCurField;
		context.codeStream[context.ip] = compiler.compileIdent(slotName.literal, context.ip);
		context.ip++;
		if (arrayExpr != null) {
			context.codeStream[context.ip++] = cast OpCode.TerminateRewindStr;
			context.codeStream[context.ip++] = cast OpCode.SetCurFieldArray;
		}
		switch (typeReq) {
			case ReqInt:
				context.codeStream[context.ip++] = cast OpCode.LoadFieldUInt;

			case ReqFloat:
				context.codeStream[context.ip++] = cast OpCode.LoadFieldFlt;

			case ReqString:
				context.codeStream[context.ip++] = cast OpCode.LoadFieldStr;

			default:
				false;
		}

		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqNone;
	}
}

@:publicFields
class SlotAssignExpr extends Expr {
	var objectExpr:Expr;
	var arrayExpr:Expr;
	var slotName:Token;
	var expr:Expr;

	public function new(objectExpr:Expr, arrayExpr:Expr, slotName:Token, expr:Expr) {
		super();
		this.objectExpr = objectExpr;
		this.arrayExpr = arrayExpr;
		this.slotName = slotName;
		this.expr = expr;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		var size = 0;
		if (typeReq != ReqString)
			size++;

		compiler.precompileIdent(slotName.literal);

		size += expr.precompile(compiler, ReqString);

		if (objectExpr != null) {
			size += objectExpr.precompile(compiler, ReqString) + 5;
		} else
			size += 5;

		if (arrayExpr != null) {
			size += arrayExpr.precompile(compiler, ReqString) + 3;
		}

		return size + 1;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = expr.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.AdvanceStr;
		if (arrayExpr != null) {
			context.ip = arrayExpr.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.AdvanceStr;
		}
		if (objectExpr != null) {
			context.ip = objectExpr.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.SetCurObject;
		} else
			context.codeStream[context.ip++] = cast OpCode.SetCurObjectNew;

		context.codeStream[context.ip++] = cast OpCode.SetCurField;
		context.codeStream[context.ip] = compiler.compileIdent(slotName.literal, context.ip);
		context.ip++;

		if (arrayExpr != null) {
			context.codeStream[context.ip++] = cast OpCode.TerminateRewindStr;
			context.codeStream[context.ip++] = cast OpCode.SetCurFieldArray;
		}

		context.codeStream[context.ip++] = cast OpCode.TerminateRewindStr;
		context.codeStream[context.ip++] = cast OpCode.SaveFieldStr;

		if (typeReq != ReqString)
			context.codeStream[context.ip++] = cast Expr.conversionOp(ReqString, typeReq);
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqString;
	}
}

@:publicFields
class SlotAssignOpExpr extends Expr {
	var objectExpr:Expr;
	var arrayExpr:Expr;
	var slotName:Token;
	var expr:Expr;
	var op:Token;

	var subType:TypeReq;
	var operand:OpCode;

	function getAssignOpTypeOp() {
		switch (op.type) {
			case PlusAssign:
				subType = ReqFloat;
				operand = Add;

			case MinusAssign:
				subType = ReqFloat;
				operand = Sub;

			case MultiplyAssign:
				subType = ReqFloat;
				operand = Mul;

			case DivideAssign:
				subType = ReqFloat;
				operand = Div;

			case ModulusAssign:
				subType = ReqInt;
				operand = Mod;

			case AndAssign:
				subType = ReqInt;
				operand = BitAnd;

			case XorAssign:
				subType = ReqInt;
				operand = Xor;

			case OrAssign:
				subType = ReqInt;
				operand = BitOr;

			case ShiftLeftAssign:
				subType = ReqInt;
				operand = Shl;

			case ShiftRightAssign:
				subType = ReqInt;
				operand = Shr;

			case PlusPlus:
				subType = ReqFloat;
				operand = Add;
				expr = new IntExpr(1);

			case MinusMinus:
				subType = ReqFloat;
				operand = Sub;
				expr = new IntExpr(1);

			default:
				throw new Exception("Unknown assignment expression");
		}
	}

	public function new(objectExpr:Expr, arrayExpr:Expr, slotName:Token, expr:Expr, op:Token) {
		super();
		this.objectExpr = objectExpr;
		this.arrayExpr = arrayExpr;
		this.slotName = slotName;
		this.expr = expr;
		this.op = op;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		getAssignOpTypeOp();

		compiler.precompileIdent(slotName.literal);

		var size = expr.precompile(compiler, subType);
		if (typeReq != subType)
			size++;
		if (arrayExpr != null)
			return size + 9 + arrayExpr.precompile(compiler, ReqString) + objectExpr.precompile(compiler, ReqString);
		else
			return size + 6 + objectExpr.precompile(compiler, ReqString);
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.ip = expr.compile(compiler, context, subType);
		if (arrayExpr != null) {
			context.ip = arrayExpr.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.AdvanceStr;
		}
		context.ip = objectExpr.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.SetCurObject;
		context.codeStream[context.ip++] = cast OpCode.SetCurField;
		context.codeStream[context.ip] = compiler.compileIdent(slotName.literal, context.ip);
		context.ip++;
		if (arrayExpr != null) {
			context.codeStream[context.ip++] = cast OpCode.TerminateRewindStr;
			context.codeStream[context.ip++] = cast OpCode.SetCurFieldArray;
		}
		context.codeStream[context.ip++] = (subType == ReqFloat) ? cast OpCode.LoadFieldFlt : cast OpCode.LoadFieldUInt;
		context.codeStream[context.ip++] = cast operand;
		context.codeStream[context.ip++] = (subType == ReqFloat) ? cast OpCode.SaveFieldFlt : cast OpCode.SaveFieldUInt;

		if (typeReq != subType)
			context.codeStream[context.ip++] = cast Expr.conversionOp(subType, typeReq);
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		getAssignOpTypeOp();
		return subType;
	}
}

@:publicFields
class ObjectDeclExpr extends Expr {
	var className:Expr;
	var parentObject:Token;
	var objectNameExpr:Expr;
	var args:Array<Expr>;
	var slotDecls:Array<SlotAssignExpr>;
	var subObjects:Array<ObjectDeclExpr>;

	var structDecl:Bool = false;

	var failOffset:Int;

	public function new(className:Expr, parentObject:Token, objectNameExpr:Expr, args:Array<Expr>, slotDecls:Array<SlotAssignExpr>,
			subObjects:Array<ObjectDeclExpr>, structDecl:Bool) {
		super();
		this.className = className;
		this.parentObject = parentObject;
		this.objectNameExpr = (objectNameExpr != null) ? objectNameExpr : new StringConstExpr("", false);
		this.args = args;
		this.slotDecls = slotDecls;
		this.subObjects = subObjects;
		this.structDecl = structDecl;
	}

	public function precompileSubObject(compiler:Compiler, typeReq:TypeReq):Int {
		var argSize = 0;
		compiler.precompileIdent(parentObject == null ? "" : parentObject.literal);
		for (expr in args) {
			argSize += expr.precompile(compiler, ReqString) + 1;
		}
		argSize += className.precompile(compiler, ReqString) + 1;

		var nameSize = objectNameExpr.precompile(compiler, ReqString);

		var slotSize = 0;
		for (slot in slotDecls) {
			slotSize += slot.precompile(compiler, ReqNone);
		}

		var subObjSize = 0;
		for (subObj in subObjects) {
			subObjSize += subObj.precompileSubObject(compiler, ReqNone);
		}
		failOffset = 10 + nameSize + argSize + slotSize + subObjSize;
		return failOffset;
	}

	public function compileSubObject(compiler:Compiler, context:CompileContext, typeReq:TypeReq, root:Bool) {
		var start = context.ip;
		context.codeStream[context.ip++] = cast OpCode.PushFrame;
		context.ip = className.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.Push;

		context.ip = objectNameExpr.compile(compiler, context, ReqString);
		context.codeStream[context.ip++] = cast OpCode.Push;
		for (expr in args) {
			context.ip = expr.compile(compiler, context, ReqString);
			context.codeStream[context.ip++] = cast OpCode.Push;
		}
		context.codeStream[context.ip++] = cast OpCode.CreateObject;
		context.codeStream[context.ip] = compiler.compileIdent(parentObject != null ? parentObject.literal : "", context.ip);
		context.ip++;
		context.codeStream[context.ip++] = cast structDecl;
		context.codeStream[context.ip++] = start + failOffset;
		for (slot in slotDecls)
			context.ip = slot.compile(compiler, context, ReqNone);
		context.codeStream[context.ip++] = cast OpCode.AddObject;
		context.codeStream[context.ip++] = cast root;
		for (subObj in subObjects)
			context.ip = subObj.compileSubObject(compiler, context, ReqNone, false);
		context.codeStream[context.ip++] = cast OpCode.EndObject;
		context.codeStream[context.ip++] = cast root || structDecl;
		return context.ip;
	}

	public override function precompile(compiler:Compiler, typeReq:TypeReq):Int {
		var ret = 2 + precompileSubObject(compiler, ReqNone);
		if (typeReq != ReqInt)
			return ret + 1;
		return ret;
	}

	public override function compile(compiler:Compiler, context:CompileContext, typeReq:TypeReq):Int {
		context.codeStream[context.ip++] = cast OpCode.LoadImmedUInt;
		context.codeStream[context.ip++] = 0;
		context.ip = compileSubObject(compiler, context, ReqInt, true);
		if (typeReq != ReqInt)
			context.codeStream[context.ip++] = cast Expr.conversionOp(ReqInt, typeReq);
		return context.ip;
	}

	public override function getPrefferredType():TypeReq {
		return ReqInt;
	}
}

@:publicFields
class FunctionDeclStmt extends Stmt {
	var functionName:Token;
	var packageName:Token;
	var args:Array<VarExpr>;
	var stmts:Array<Stmt>;
	var namespace:Token;

	var endOffset:Int;
	var argc:Int;

	public function new(functionName:Token, args:Array<VarExpr>, stmts:Array<Stmt>, namespace:Token) {
		this.functionName = functionName;
		this.args = args;
		this.stmts = stmts;
		this.namespace = namespace;
	}

	public override function precompileStmt(compiler:Compiler, loopCount:Int):Int {
		compiler.setTable(StringTable, Function);
		compiler.setTable(FloatTable, Function);

		argc = args.length;

		compiler.inFunction = true;

		compiler.precompileIdent(functionName.literal);
		compiler.precompileIdent(namespace != null ? namespace.literal : "");
		compiler.precompileIdent(packageName != null ? packageName.literal : "");

		var subSize = Stmt.precompileBlock(compiler, stmts, 0);
		compiler.inFunction = false;

		compiler.setTable(StringTable, Global);
		compiler.setTable(FloatTable, Global);

		endOffset = argc + subSize + 8;
		return endOffset;
	}

	public override function compileStmt(compiler:Compiler, context:CompileContext):Int {
		var start = context.ip;
		context.codeStream[context.ip++] = cast OpCode.FuncDecl;
		context.codeStream[context.ip] = compiler.compileIdent(functionName.literal, context.ip);
		context.ip++;
		context.codeStream[context.ip] = compiler.compileIdent(namespace != null ? namespace.literal : null, context.ip);
		context.ip++;
		context.codeStream[context.ip] = compiler.compileIdent(packageName != null ? packageName.literal : null, context.ip);
		context.ip++;
		context.codeStream[context.ip++] = cast stmts != null;
		context.codeStream[context.ip++] = start + endOffset;
		context.codeStream[context.ip++] = argc;
		for (arg in args) {
			context.codeStream[context.ip] = compiler.compileIdent((arg.type == Global ? "$" : "%") + arg.name.literal, context.ip);
			context.ip++;
		}
		compiler.inFunction = true;

		var bp = context.breakPoint;
		var cp = context.continuePoint;
		context.breakPoint = 0;
		context.continuePoint = 0;
		context.ip = Stmt.compileBlock(compiler, context, stmts);
		context.breakPoint = bp;
		context.continuePoint = cp;
		compiler.inFunction = false;
		context.codeStream[context.ip++] = cast OpCode.Return;
		return context.ip;
	}
}
