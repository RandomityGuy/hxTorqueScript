package optimizer;

import expr.Expr;
import expr.Expr.ParenthesisExpr;
import expr.Expr.ReturnStmt;
import expr.Expr.IfStmt;
import expr.Expr.LoopStmt;
import expr.Expr.BinaryExpr;
import expr.Expr.FloatBinaryExpr;
import expr.Expr.IntBinaryExpr;
import expr.Expr.StrEqExpr;
import expr.Expr.StrCatExpr;
import expr.Expr.CommaCatExpr;
import expr.Expr.ConditionalExpr;
import expr.Expr.IntUnaryExpr;
import expr.Expr.FloatUnaryExpr;
import expr.Expr.VarExpr;
import expr.Expr.IntExpr;
import expr.Expr.FloatExpr;
import expr.Expr.StringConstExpr;
import expr.Expr.ConstantExpr;
import expr.Expr.AssignExpr;
import expr.Expr.AssignOpExpr;
import expr.Expr.FuncCallExpr;
import expr.Expr.SlotAccessExpr;
import expr.Expr.SlotAssignExpr;
import expr.Expr.SlotAssignOpExpr;
import expr.Expr.ObjectDeclExpr;
import expr.Expr.FunctionDeclStmt;
import expr.Expr.Stmt;

class ConstantFoldingPass implements IOptimizerPass {
	public function new() {}

	public function optimize(ast:Array<Stmt>) {
		for (stmt in ast) {
			stmt.visitStmt(this);
		}
	}

	public function visitStmt(stmt:Stmt) {}

	public function visitBreakStmt(stmt:BreakStmt) {}

	public function visitContinueStmt(stmt:ContinueStmt) {}

	public function visitExpr(expr:Expr) {}

	public function visitParenthesisExpr(expr:ParenthesisExpr) {}

	public function visitReturnStmt(stmt:ReturnStmt) {}

	public function visitIfStmt(stmt:IfStmt) {}

	public function visitLoopStmt(stmt:LoopStmt) {}

	public function visitBinaryExpr(expr:BinaryExpr) {}

	public function visitFloatBinaryExpr(expr:FloatBinaryExpr) {
		if (Std.isOfType(expr.left, ParenthesisExpr))
			expr.left = cast(expr.left, ParenthesisExpr).expr;

		if (Std.isOfType(expr.right, ParenthesisExpr))
			expr.right = cast(expr.right, ParenthesisExpr).expr;

		if (Std.isOfType(expr.left, BinaryExpr))
			if (cast(expr.left, BinaryExpr).optimized)
				expr.left = cast(expr.left, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, BinaryExpr))
			if (cast(expr.right, BinaryExpr).optimized)
				expr.right = cast(expr.right, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.left, IntUnaryExpr))
			if (cast(expr.left, IntUnaryExpr).optimized)
				expr.left = cast(expr.left, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, IntUnaryExpr))
			if (cast(expr.right, IntUnaryExpr).optimized)
				expr.right = cast(expr.right, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.left, FloatUnaryExpr))
			if (cast(expr.left, FloatUnaryExpr).optimized)
				expr.left = cast(expr.left, FloatUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, FloatUnaryExpr))
			if (cast(expr.right, FloatUnaryExpr).optimized)
				expr.right = cast(expr.right, FloatUnaryExpr).optimizedExpr;

		// Check if both left and right expr can be properly folded
		if ((Std.isOfType(expr.left, IntExpr) || Std.isOfType(expr.left, FloatExpr) || Std.isOfType(expr.left, StringConstExpr))
			&& (Std.isOfType(expr.right, IntExpr) || Std.isOfType(expr.right, FloatExpr) || Std.isOfType(expr.right, StringConstExpr))) {
			var lValue:Float = 0;
			var rValue:Float = 0;

			if (Std.isOfType(expr.left, IntExpr))
				lValue = cast(expr.left, IntExpr).value;
			else if (Std.isOfType(expr.left, FloatExpr))
				lValue = cast(expr.left, FloatExpr).value;
			else if (Std.isOfType(expr.left, StringConstExpr))
				lValue = Compiler.stringToNumber(cast(expr.left, StringConstExpr).value);

			if (Std.isOfType(expr.right, IntExpr))
				rValue = cast(expr.right, IntExpr).value;
			else if (Std.isOfType(expr.right, FloatExpr))
				rValue = cast(expr.right, FloatExpr).value;
			else if (Std.isOfType(expr.right, StringConstExpr))
				rValue = Compiler.stringToNumber(cast(expr.right, StringConstExpr).value);

			var result:Float = switch (expr.op.type) {
				case Plus:
					lValue + rValue;

				case Minus:
					lValue - rValue;

				case Divide:
					lValue / rValue;

				case Multiply:
					lValue * rValue;

				default:
					0;
			}

			expr.optimized = true;
			expr.optimizedExpr = new FloatExpr(expr.lineNo, result);
		}
	}

	public function visitIntBinaryExpr(expr:IntBinaryExpr) {
		if (Std.isOfType(expr.left, ParenthesisExpr))
			expr.left = cast(expr.left, ParenthesisExpr).expr;

		if (Std.isOfType(expr.right, ParenthesisExpr))
			expr.right = cast(expr.right, ParenthesisExpr).expr;

		if (Std.isOfType(expr.left, BinaryExpr))
			if (cast(expr.left, BinaryExpr).optimized)
				expr.left = cast(expr.left, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, BinaryExpr))
			if (cast(expr.right, BinaryExpr).optimized)
				expr.right = cast(expr.right, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.left, IntUnaryExpr))
			if (cast(expr.left, IntUnaryExpr).optimized)
				expr.left = cast(expr.left, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, IntUnaryExpr))
			if (cast(expr.right, IntUnaryExpr).optimized)
				expr.right = cast(expr.right, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.left, FloatUnaryExpr))
			if (cast(expr.left, FloatUnaryExpr).optimized)
				expr.left = cast(expr.left, FloatUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, FloatUnaryExpr))
			if (cast(expr.right, FloatUnaryExpr).optimized)
				expr.right = cast(expr.right, FloatUnaryExpr).optimizedExpr;

		// Check if both left and right expr can be properly folded
		if ((Std.isOfType(expr.left, IntExpr) || Std.isOfType(expr.left, FloatExpr) || Std.isOfType(expr.left, StringConstExpr))
			&& (Std.isOfType(expr.right, IntExpr) || Std.isOfType(expr.right, FloatExpr) || Std.isOfType(expr.right, StringConstExpr))) {
			expr.getSubTypeOperand();
			if (expr.subType == ReqFloat) {
				var lValue:Float = 0;
				var rValue:Float = 0;

				if (Std.isOfType(expr.left, IntExpr))
					lValue = cast(expr.left, IntExpr).value;
				else if (Std.isOfType(expr.left, FloatExpr))
					lValue = cast(expr.left, FloatExpr).value;
				else if (Std.isOfType(expr.left, StringConstExpr))
					lValue = Compiler.stringToNumber(cast(expr.left, StringConstExpr).value);

				if (Std.isOfType(expr.right, IntExpr))
					rValue = cast(expr.right, IntExpr).value;
				else if (Std.isOfType(expr.right, FloatExpr))
					rValue = cast(expr.right, FloatExpr).value;
				else if (Std.isOfType(expr.right, StringConstExpr))
					rValue = Compiler.stringToNumber(cast(expr.right, StringConstExpr).value);

				var result:Int = switch (expr.op.type) {
					case TokenType.LessThan:
						lValue < rValue ? 1 : 0;

					case LessThanEqual:
						lValue <= rValue ? 1 : 0;

					case GreaterThan:
						lValue > rValue ? 1 : 0;

					case GreaterThanEqual:
						lValue >= rValue ? 1 : 0;

					case Equal:
						lValue == rValue ? 1 : 0;

					case NotEqual:
						lValue != rValue ? 1 : 0;

					default:
						0;
				}

				expr.optimized = true;
				expr.optimizedExpr = new IntExpr(expr.lineNo, result);
				return;
			}

			if (expr.subType == ReqInt) {
				var lValue:Int = 0;
				var rValue:Int = 0;

				if (Std.isOfType(expr.left, IntExpr))
					lValue = cast(expr.left, IntExpr).value;
				else if (Std.isOfType(expr.left, FloatExpr))
					lValue = cast cast(expr.left, FloatExpr).value;
				else if (Std.isOfType(expr.left, StringConstExpr))
					lValue = cast Compiler.stringToNumber(cast(expr.left, StringConstExpr).value);

				if (Std.isOfType(expr.right, IntExpr))
					rValue = cast(expr.right, IntExpr).value;
				else if (Std.isOfType(expr.right, FloatExpr))
					rValue = cast cast(expr.right, FloatExpr).value;
				else if (Std.isOfType(expr.right, StringConstExpr))
					rValue = cast Compiler.stringToNumber(cast(expr.right, StringConstExpr).value);

				var result:Int = switch (expr.op.type) {
					case TokenType.BitwiseXor:
						lValue ^ rValue;

					case TokenType.Modulus:
						lValue % rValue;

					case TokenType.BitwiseAnd:
						lValue & rValue;

					case TokenType.BitwiseOr:
						lValue | rValue;

					case TokenType.LogicalOr:
						((lValue > 0 || rValue > 0) ? 1 : 0);

					case TokenType.LogicalAnd:
						((lValue > 0 && rValue > 0) ? 1 : 0);

					case TokenType.LeftBitShift:
						lValue << rValue;

					case TokenType.RightBitShift:
						lValue >> rValue;

					default:
						0;
				}

				expr.optimized = true;
				expr.optimizedExpr = new IntExpr(expr.lineNo, result);
				return;
			}
		}
	}

	public function visitStrEqExpr(expr:StrEqExpr) {
		if (Std.isOfType(expr.left, ParenthesisExpr))
			expr.left = cast(expr.left, ParenthesisExpr).expr;

		if (Std.isOfType(expr.right, ParenthesisExpr))
			expr.right = cast(expr.right, ParenthesisExpr).expr;

		if (Std.isOfType(expr.left, BinaryExpr))
			if (cast(expr.left, BinaryExpr).optimized)
				expr.left = cast(expr.left, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, BinaryExpr))
			if (cast(expr.right, BinaryExpr).optimized)
				expr.right = cast(expr.right, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.left, IntUnaryExpr))
			if (cast(expr.left, IntUnaryExpr).optimized)
				expr.left = cast(expr.left, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, IntUnaryExpr))
			if (cast(expr.right, IntUnaryExpr).optimized)
				expr.right = cast(expr.right, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.left, FloatUnaryExpr))
			if (cast(expr.left, FloatUnaryExpr).optimized)
				expr.left = cast(expr.left, FloatUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, FloatUnaryExpr))
			if (cast(expr.right, FloatUnaryExpr).optimized)
				expr.right = cast(expr.right, FloatUnaryExpr).optimizedExpr;

		// Check if both left and right expr can be properly folded
		if ((Std.isOfType(expr.left, IntExpr) || Std.isOfType(expr.left, FloatExpr) || Std.isOfType(expr.left, StringConstExpr))
			&& (Std.isOfType(expr.right, IntExpr) || Std.isOfType(expr.right, FloatExpr) || Std.isOfType(expr.right, StringConstExpr))) {
			var lValue:String = "";
			var rValue:String = "";

			if (Std.isOfType(expr.left, IntExpr))
				lValue = '${cast (expr.left, IntExpr).value}';
			else if (Std.isOfType(expr.left, FloatExpr))
				lValue = '${cast (expr.left, FloatExpr).value}';
			else if (Std.isOfType(expr.left, StringConstExpr))
				lValue = '${cast (expr.left, StringConstExpr).value}';

			if (Std.isOfType(expr.right, IntExpr))
				rValue = '${cast (expr.right, IntExpr).value}';
			else if (Std.isOfType(expr.right, FloatExpr))
				rValue = '${cast (expr.right, FloatExpr).value}';
			else if (Std.isOfType(expr.right, StringConstExpr))
				rValue = cast(expr.right, StringConstExpr).value;

			var result = switch (expr.op.type) {
				case TokenType.StringEquals:
					lValue == rValue ? 1 : 0;

				case TokenType.StringNotEquals:
					lValue != rValue ? 1 : 0;

				default:
					0;
			}

			expr.optimized = true;
			expr.optimizedExpr = new IntExpr(expr.lineNo, cast result);
		}
	}

	public function visitStrCatExpr(expr:StrCatExpr) {
		if (Std.isOfType(expr.left, ParenthesisExpr))
			expr.left = cast(expr.left, ParenthesisExpr).expr;

		if (Std.isOfType(expr.right, ParenthesisExpr))
			expr.right = cast(expr.right, ParenthesisExpr).expr;

		if (Std.isOfType(expr.left, BinaryExpr))
			if (cast(expr.left, BinaryExpr).optimized)
				expr.left = cast(expr.left, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, BinaryExpr))
			if (cast(expr.right, BinaryExpr).optimized)
				expr.right = cast(expr.right, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.left, IntUnaryExpr))
			if (cast(expr.left, IntUnaryExpr).optimized)
				expr.left = cast(expr.left, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, IntUnaryExpr))
			if (cast(expr.right, IntUnaryExpr).optimized)
				expr.right = cast(expr.right, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.left, FloatUnaryExpr))
			if (cast(expr.left, FloatUnaryExpr).optimized)
				expr.left = cast(expr.left, FloatUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.right, FloatUnaryExpr))
			if (cast(expr.right, FloatUnaryExpr).optimized)
				expr.right = cast(expr.right, FloatUnaryExpr).optimizedExpr;

		// Check if both left and right expr can be properly folded
		if ((Std.isOfType(expr.left, IntExpr) || Std.isOfType(expr.left, FloatExpr) || Std.isOfType(expr.left, StringConstExpr))
			&& (Std.isOfType(expr.right, IntExpr) || Std.isOfType(expr.right, FloatExpr) || Std.isOfType(expr.right, StringConstExpr))) {
			var lValue:String = "";
			var rValue:String = "";

			if (Std.isOfType(expr.left, IntExpr))
				lValue = '${cast (expr.left, IntExpr).value}';
			else if (Std.isOfType(expr.left, FloatExpr))
				lValue = '${cast (expr.left, FloatExpr).value}';
			else if (Std.isOfType(expr.left, StringConstExpr))
				lValue = '${cast (expr.left, StringConstExpr).value}';

			if (Std.isOfType(expr.right, IntExpr))
				rValue = '${cast (expr.right, IntExpr).value}';
			else if (Std.isOfType(expr.right, FloatExpr))
				rValue = '${cast (expr.right, FloatExpr).value}';
			else if (Std.isOfType(expr.right, StringConstExpr))
				rValue = cast(expr.right, StringConstExpr).value;

			var result = switch (expr.op.type) {
				case Concat:
					lValue + rValue;

				case SpaceConcat:
					lValue + " " + rValue;

				case TabConcat:
					lValue + "\t" + rValue;

				case NewlineConcat:
					lValue + "\n" + rValue;

				default:
					"";
			}

			expr.optimized = true;
			expr.optimizedExpr = new StringConstExpr(expr.lineNo, result, false);
		}
	}

	public function visitCommatCatExpr(expr:CommaCatExpr) {}

	public function visitConditionalExpr(expr:ConditionalExpr) {}

	public function visitIntUnaryExpr(expr:IntUnaryExpr) {
		if (Std.isOfType(expr.expr, ParenthesisExpr))
			expr.expr = cast(expr.expr, ParenthesisExpr).expr;

		if (Std.isOfType(expr.expr, BinaryExpr))
			if (cast(expr.expr, BinaryExpr).optimized)
				expr.expr = cast(expr.expr, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.expr, IntUnaryExpr))
			if (cast(expr.expr, IntUnaryExpr).optimized)
				expr.expr = cast(expr.expr, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.expr, FloatUnaryExpr))
			if (cast(expr.expr, FloatUnaryExpr).optimized)
				expr.expr = cast(expr.expr, FloatUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.expr, IntExpr) || Std.isOfType(expr.expr, FloatExpr) || Std.isOfType(expr.expr, StringConstExpr)) {
			var value:Float = 0;

			if (Std.isOfType(expr.expr, IntExpr))
				value = cast(expr.expr, IntExpr).value;
			else if (Std.isOfType(expr.expr, FloatExpr))
				value = cast(expr.expr, FloatExpr).value;
			else if (Std.isOfType(expr.expr, StringConstExpr))
				value = Compiler.stringToNumber(cast(expr.expr, StringConstExpr).value);

			var result:Int = switch (expr.op.type) {
				case TokenType.Not:
					(value == 0 ? 1 : 0);

				case TokenType.Tilde:
					~cast value;

				default:
					0;
			}

			expr.optimized = true;
			expr.optimizedExpr = new IntExpr(expr.lineNo, result);
		}
	}

	public function visitFloatUnaryExpr(expr:FloatUnaryExpr) {
		if (Std.isOfType(expr.expr, ParenthesisExpr))
			expr.expr = cast(expr.expr, ParenthesisExpr).expr;

		if (Std.isOfType(expr.expr, BinaryExpr))
			if (cast(expr.expr, BinaryExpr).optimized)
				expr.expr = cast(expr.expr, BinaryExpr).optimizedExpr;

		if (Std.isOfType(expr.expr, IntUnaryExpr))
			if (cast(expr.expr, IntUnaryExpr).optimized)
				expr.expr = cast(expr.expr, IntUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.expr, FloatUnaryExpr))
			if (cast(expr.expr, FloatUnaryExpr).optimized)
				expr.expr = cast(expr.expr, FloatUnaryExpr).optimizedExpr;

		if (Std.isOfType(expr.expr, IntExpr) || Std.isOfType(expr.expr, FloatExpr) || Std.isOfType(expr.expr, StringConstExpr)) {
			var value:Float = 0;

			if (Std.isOfType(expr.expr, IntExpr))
				value = cast(expr.expr, IntExpr).value;
			else if (Std.isOfType(expr.expr, FloatExpr))
				value = cast(expr.expr, FloatExpr).value;
			else if (Std.isOfType(expr.expr, StringConstExpr))
				value = Compiler.stringToNumber(cast(expr.expr, StringConstExpr).value);

			var result:Float = -value;

			expr.optimized = true;
			expr.optimizedExpr = new FloatExpr(expr.lineNo, result);
		}
	}

	public function visitVarExpr(expr:VarExpr) {}

	public function visitIntExpr(expr:IntExpr) {}

	public function visitFloatExpr(expr:FloatExpr) {}

	public function visitStringConstExpr(expr:StringConstExpr) {}

	public function visitConstantExpr(expr:ConstantExpr) {}

	public function visitAssignExpr(expr:AssignExpr) {}

	public function visitAssignOpExpr(expr:AssignOpExpr) {}

	public function visitFuncCallExpr(expr:FuncCallExpr) {}

	public function visitSlotAccessExpr(expr:SlotAccessExpr) {}

	public function visitSlotAssignExpr(expr:SlotAssignExpr) {}

	public function visitSlotAssignOpExpr(expr:SlotAssignOpExpr) {}

	public function visitObjectDeclExpr(expr:ObjectDeclExpr) {}

	public function visitFunctionDeclStmt(stmt:FunctionDeclStmt) {}

	public function getLevel():Int {
		return 1;
	}
}
