package;

import expr.Expr;
import expr.Expr.ContinueStmt;
import expr.Expr.BreakStmt;
import expr.Expr.ReturnStmt;
import expr.Expr.ParenthesisExpr;
import expr.Expr.Stmt;

interface IOptimizerPass extends IASTVisitor {
	function optimize(ast:Array<Stmt>):Void;
	function getLevel():Int;
}
