package;

import expr.Expr;
import expr.Expr.ContinueStmt;
import expr.Expr.BreakStmt;
import expr.Expr.ReturnStmt;
import expr.Expr.ParenthesisExpr;
import expr.Expr.Stmt;

interface IASTVisitor {
	function visitStmt(stmt:Stmt):Void;

	function visitBreakStmt(stmt:BreakStmt):Void;

	function visitContinueStmt(stmt:ContinueStmt):Void;

	function visitExpr(expr:Expr):Void;

	function visitParenthesisExpr(expr:ParenthesisExpr):Void;

	function visitReturnStmt(stmt:ReturnStmt):Void;

	function visitIfStmt(stmt:IfStmt):Void;

	function visitLoopStmt(stmt:LoopStmt):Void;

	function visitBinaryExpr(expr:BinaryExpr):Void;
	function visitFloatBinaryExpr(expr:FloatBinaryExpr):Void;

	function visitIntBinaryExpr(expr:IntBinaryExpr):Void;

	function visitStrEqExpr(expr:StrEqExpr):Void;

	function visitStrCatExpr(expr:StrCatExpr):Void;

	function visitCommatCatExpr(expr:CommaCatExpr):Void;

	function visitConditionalExpr(expr:ConditionalExpr):Void;

	function visitIntUnaryExpr(expr:IntUnaryExpr):Void;

	function visitFloatUnaryExpr(expr:FloatUnaryExpr):Void;

	function visitVarExpr(expr:VarExpr):Void;

	function visitIntExpr(expr:IntExpr):Void;

	function visitFloatExpr(expr:FloatExpr):Void;

	function visitStringConstExpr(expr:StringConstExpr):Void;

	function visitConstantExpr(expr:ConstantExpr):Void;

	function visitAssignExpr(expr:AssignExpr):Void;

	function visitAssignOpExpr(expr:AssignOpExpr):Void;

	function visitFuncCallExpr(expr:FuncCallExpr):Void;

	function visitSlotAccessExpr(expr:SlotAccessExpr):Void;

	function visitSlotAssignExpr(expr:SlotAssignExpr):Void;

	function visitSlotAssignOpExpr(expr:SlotAssignOpExpr):Void;

	function visitObjectDeclExpr(expr:ObjectDeclExpr):Void;

	function visitFunctionDeclStmt(stmt:FunctionDeclStmt):Void;
}
