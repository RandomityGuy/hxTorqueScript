package expr;

@:publicFields
abstract class Expr {}

@:publicFields
class Label extends Expr {
	var name:String;

	public function new(name:String) {
		this.name = name;
	}
}

@:publicFields
class FunctionDeclaration extends Expr {
	var namespace:Null<Label>;
	var name:Label;
	var parameters:Null<FunctionDeclarationParameters>;
	var exprs:Array<ExprStatement>;

	public function new(namespace:Null<Label>, name:Label, parameters:Null<FunctionDeclarationParameters>, exprs:Array<ExprStatement>) {
		this.namespace = namespace;
		this.name = name;
		this.parameters = parameters;
		this.exprs = exprs;
	}
}

@:publicFields
class FunctionDeclarationParameters extends Expr {
	var params:Array<LocalVariable>;

	public function new(params:Array<LocalVariable>) {
		this.params = params;
	}
}

@:publicFields
class LocalVariable extends Expr {
	var name:Label;
	var namespace:Label;

	public function new(name:Label, namespace:Null<Label>) {
		this.name = name;
		this.namespace = namespace;
	}
}

@:publicFields
class GlobalVariable extends Expr {
	var name:Label;
	var namespace:Label;

	public function new(name:Label, namespace:Null<Label>) {
		this.name = name;
		this.namespace = namespace;
	}
}

@:publicFields
class LocalArray extends Expr {
	var variable:LocalVariable;
	var subscript:Array<Expr>;

	public function new(variable:LocalVariable, subscript:Array<Expr>) {
		this.variable = variable;
		this.subscript = subscript;
	}
}

@:publicFields
class GlobalArray extends Expr {
	var variable:GlobalVariable;
	var subscript:Array<Expr>;

	public function new(variable:GlobalVariable, subscript:Array<Expr>) {
		this.variable = variable;
		this.subscript = subscript;
	}
}

@:publicFields
class ExprStatement extends Expr {}

@:publicFields
class Expression extends Expr {}

@:publicFields
class PackageDeclaration extends Expr {
	var name:Label;
	var functionDeclarations:Array<FunctionDeclaration>;

	public function new(name:Label, functionDeclarations:Array<FunctionDeclaration>) {
		this.name = name;
		this.functionDeclarations = functionDeclarations;
	}
}

@:publicFields
class WhileControl extends ExprStatement {
	var condition:Expression;
	var exprs:Array<ExprStatement>;

	public function new(condition:Expression, exprs:Array<ExprStatement>) {
		this.condition = condition;
		this.exprs = exprs;
	}
}

@:publicFields
class ForControl extends ExprStatement {
	var first:Expr;
	var second:Expr;
	var third:Expr;
	var exprs:Array<ExprStatement>;

	public function new(first:Expr, second:Expr, third:Expr, exprs:Array<ExprStatement>) {
		this.first = first;
		this.second = second;
		this.third = third;
		this.exprs = exprs;
	}
}

@:publicFields
class IfControl extends ExprStatement {
	var condition:Expr;
	var exprs:Array<ExprStatement>;
	var elseCtrl:Null<ElseControl>;

	public function new(condition:Expr, exprs:Array<ExprStatement>, elseCtrl:Null<ElseControl>) {
		this.condition = condition;
		this.exprs = exprs;
		this.elseCtrl = elseCtrl;
	}
}

@:publicFields
class ElseControl extends ExprStatement {
	var exprs:Array<ExprStatement>;

	public function new(exprs:Array<ExprStatement>) {
		this.exprs = exprs;
	}
}

@:publicFields
class SwitchControl extends ExprStatement {
	var isStringSwitch:Bool;
	var condition:Expr;
	var cases:Array<CaseControl>;
	var defaultCase:DefaultControl;

	public function new(isStringSwitch:Bool, condition:Expr, cases:Array<CaseControl>, defaultCase:DefaultControl) {
		this.isStringSwitch = isStringSwitch;
		this.condition = condition;
		this.cases = cases;
		this.defaultCase = defaultCase;
	}
}

@:publicFields
class CaseControl extends ExprStatement {
	var conditions:Array<Expression>;
	var exprs:Array<ExprStatement>;

	public function new(conditions:Array<Expression>, exprs:Array<ExprStatement>) {
		this.conditions = conditions;
		this.exprs = exprs;
	}
}

@:publicFields
class DefaultControl extends ExprStatement {
	var exprs:Array<ExprStatement>;

	public function new(exprs:Array<ExprStatement>) {
		this.exprs = exprs;
	}
}

@:publicFields
class BreakControl extends ExprStatement {
	public function new() {}
}

@:publicFields
class ContinueControl extends ExprStatement {
	public function new() {}
}

@:publicFields
class ReturnControl extends ExprStatement {
	var expr:Null<Expr>;

	public function new(expr:Null<Expr>) {
		this.expr = expr;
	}
}

@:publicFields
class Value extends Expr {}

@:publicFields
class NumberValue extends Value {
	var value:Token;

	public function new(value:Token) {
		this.value = value;
	}
}

@:publicFields
class StringValue extends Value {
	var value:Token;

	public function new(value:Token) {
		this.value = value;
	}
}

@:publicFields
class BooleanValue extends Value {
	var value:Token;

	public function new(value:Token) {
		this.value = value;
	}
}

@:publicFields
class LabelValue extends Value {
	var value:Token;

	public function new(value:Token) {
		this.value = value;
	}
}

@:publicFields
class FunctionCall extends ExprStatement {
	var namespace:Null<Label>;
	var name:Label;
	var arguments:Array<Expr>;

	public function new(namespace:Null<Label>, name:Label, arguments:Array<Expr>) {
		this.namespace = namespace;
		this.name = name;
		this.arguments = arguments;
	}
}

@:publicFields
class MethodCall extends ExprStatement {
	var lhs:Expr;
	var rhs:FunctionCall;

	public function new(lhs:Expr, rhs:FunctionCall) {
		this.lhs = lhs;
		this.rhs = rhs;
	}
}

@:publicFields
class FieldExpr extends Expression {
	var name:Label;

	public function new(name:Label) {
		this.name = name;
	}
}

@:publicFields
class FieldArrayExpr extends Expression {
	var name:Label;
	var subscript:Array<Expr>;

	public function new(name:Label, subscript:Array<Expr>) {
		this.name = name;
		this.subscript = subscript;
	}
}

@:publicFields
class ChainExpr extends Expr {
	var left:Expr;
	var right:Expr;

	public function new(left:Expr, right:Expr) {
		this.left = left;
		this.right = right;
	}
}

@:publicFields
class AssignmentExpr extends ExprStatement {
	var token:Token;
	var left:Expr;
	var right:Expr;

	public function new(token:Token, left:Expr, right:Expr) {
		this.token = token;
		this.left = left;
		this.right = right;
	}
}

@:publicFields
class PostfixExpr extends ExprStatement {
	var token:Token;
	var expr:Expr;

	public function new(token:Token, expr:Expr) {
		this.token = token;
		this.expr = expr;
	}
}

@:publicFields
class PostfixExpression extends Expression {
	var token:Token;
	var expr:Expr;

	public function new(token:Token, expr:Expr) {
		this.token = token;
		this.expr = expr;
	}
}

@:publicFields
class FieldAssignmentExpr extends ExprStatement {
	var field:Label;
	var subscript:Null<Array<Expr>>;
	var rhs:Expr;

	public function new(field:Label, subscript:Null<Array<Expr>>, rhs:Expr) {
		this.field = field;
		this.subscript = subscript;
		this.rhs = rhs;
	}
}

@:publicFields
class DatablockDeclaration extends ExprStatement {
	var className:Label;
	var name:Label;
	var parent:Null<Label>;
	var fields:Array<FieldAssignmentExpr>;

	public function new(className:Label, name:Label, parent:Null<Label>, fields:Array<FieldAssignmentExpr>) {
		this.className = className;
		this.name = name;
		this.parent = parent;
		this.fields = fields;
	}
}

@:publicFields
class ObjectDeclaration extends ExprStatement {
	var className:Expr;
	var objectName:Expr;

	var parentClassName:Expr;

	var fields:Array<FieldAssignmentExpr>;
	var subObjects:Array<ObjectDeclaration>;

	public function new(className:Expr, objectName:Expr, parentClassName:Expr, fields:Array<FieldAssignmentExpr>, subObjects:Array<ObjectDeclaration>) {
		this.className = className;
		this.objectName = objectName;
		this.parentClassName = parentClassName;
		this.fields = fields;
		this.subObjects = subObjects;
	}
}

@:publicFields
class UnaryExpression extends Expression {
	var expr:Expression;
	var token:Token;

	public function new(expr:Expression, token:Token) {
		this.expr = expr;
		this.token = token;
	}
}

@:publicFields
class BitwiseExpression extends Expression {
	var lhs:Expression;
	var op:Token;
	var rhs:Expression;

	public function new(lhs:Expression, op:Token, rhs:Expression) {
		this.lhs = lhs;
		this.op = op;
		this.rhs = rhs;
	}
}

@:publicFields
class ArithmeticExpression extends Expression {
	var lhs:Expression;
	var op:Token;
	var rhs:Expression;

	public function new(lhs:Expression, op:Token, rhs:Expression) {
		this.lhs = lhs;
		this.op = op;
		this.rhs = rhs;
	}
}

@:publicFields
class TernaryExpression extends Expression {
	var condition:Expression;
	var trueExpression:Expression;
	var falseExpression:Expression;

	public function new(condition:Expression, trueExpression:Expression, falseExpression:Expression) {
		this.condition = condition;
		this.trueExpression = trueExpression;
		this.falseExpression = falseExpression;
	}
}

@:publicFields
class RelationalExpression extends Expression {
	var lhs:Expression;
	var op:Token;
	var rhs:Expression;

	public function new(lhs:Expression, op:Token, rhs:Expression) {
		this.lhs = lhs;
		this.op = op;
		this.rhs = rhs;
	}
}

@:publicFields
class BitshiftExpression extends Expression {
	var lhs:Expression;
	var op:Token;
	var rhs:Expression;

	public function new(lhs:Expression, op:Token, rhs:Expression) {
		this.lhs = lhs;
		this.op = op;
		this.rhs = rhs;
	}
}

@:publicFields
class LogicalExpression extends Expression {
	var lhs:Expression;
	var op:Token;
	var rhs:Expression;

	public function new(lhs:Expression, op:Token, rhs:Expression) {
		this.lhs = lhs;
		this.op = op;
		this.rhs = rhs;
	}
}

@:publicFields
class EqualityExpression extends Expression {
	var lhs:Expression;
	var op:Token;
	var rhs:Expression;

	public function new(lhs:Expression, op:Token, rhs:Expression) {
		this.lhs = lhs;
		this.op = op;
		this.rhs = rhs;
	}
}

@:publicFields
class ConcatenationExpression extends Expression {
	var lhs:Expression;
	var op:Token;
	var rhs:Expression;

	public function new(lhs:Expression, op:Token, rhs:Expression) {
		this.lhs = lhs;
		this.op = op;
		this.rhs = rhs;
	}
}

@:publicFields
class ValueExpression extends Expression {
	var value:Expr;

	public function new(value:Expr) {
		this.value = value;
	}
}

@:publicFields
class ParenthesizedExpression extends Expression {
	var expression:Expression;

	public function new(expression:Expression) {
		this.expression = expression;
	}
}

@:publicFields
class ChainExpression extends Expression {
	var chain:Expr;

	public function new(chain:Expr) {
		this.chain = chain;
	}
}
