package expr;

typedef CaseExpr = {
	conditions:Array<Expr>,
	stmts:Array<Stmt>,
	defaultStmts:Null<Array<Stmt>>,
	next:Null<CaseExpr>
}

@:publicFields
class Stmt {}

@:publicFields
class BreakStmt extends Stmt {
	public function new() {}
}

@:publicFields
class ContinueStmt extends Stmt {
	public function new() {}
}

@:publicFields
class Expr extends Stmt {
	public function new() {}
}

@:publicFields
class ReturnStmt extends Stmt {
	var expr:Null<Expr>;

	public function new(expr:Null<Expr>) {
		this.expr = expr;
	}
}

@:publicFields
class IfStmt extends Stmt {
	var condition:Expr;
	var body:Array<Stmt>;
	var elseBlock:Null<Array<Stmt>>;

	public function new(condition:Expr, body:Array<Stmt>, elseBlock:Array<Stmt>) {
		this.condition = condition;
		this.body = body;
		this.elseBlock = elseBlock;
	}
}

@:publicFields
class LoopStmt extends Stmt {
	var condition:Expr;
	var init:Null<Expr>;
	var end:Null<Expr>;
	var body:Array<Stmt>;

	public function new(condition:Expr, init:Expr, end:Expr, body:Array<Stmt>) {
		this.condition = condition;
		this.init = init;
		this.end = end;
		this.body = body;
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
}

@:publicFields
class IntBinaryExpr extends BinaryExpr {
	public function new(left:Expr, right:Expr, op:Token) {
		super();
		this.left = left;
		this.right = right;
		this.op = op;
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
}

@:publicFields
class StrCatExpr extends BinaryExpr {
	public function new(left:Expr, right:Expr, op:Token) {
		super();
		this.left = left;
		this.right = right;
		this.op = op;
	}
}

@:publicFields
class CommaCatExpr extends BinaryExpr {
	public function new(left:Expr, right:Expr) {
		super();
		this.left = left;
		this.right = right;
	}
}

@:publicFields
class ConditionalExpr extends Expr {
	var condition:Expr;
	var trueExpr:Expr;
	var falseExpr:Expr;

	public function new(condition:Expr, trueExpr:Expr, falseExpr:Expr) {
		super();
		this.condition = condition;
		this.trueExpr = trueExpr;
		this.falseExpr = falseExpr;
	}
}

@:publicFields
class IntUnaryExpr extends Expr {
	var expr:Expr;
	var op:Token;

	public function new(expr:Expr, op:Token) {
		super();
		this.expr = expr;
		this.op = op;
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
}

enum VarType {
	Global;
	Local;
}

@:publicFields
class VarExpr extends Expr {
	var name:Token;
	var arrayIndex:Null<Array<Expr>>;

	var type:VarType;

	function new(name:Token, arrayIndex:Null<Array<Expr>>, type:VarType) {
		super();
		this.name = name;
		this.arrayIndex = arrayIndex;
		this.type = type;
	}
}

@:publicFields
class IntExpr extends Expr {
	var value:Int;

	public function new(value:Int) {
		super();
		this.value = value;
	}
}

@:publicFields
class FloatExpr extends Expr {
	var value:Float;

	public function new(value:Float) {
		super();
		this.value = value;
	}
}

@:publicFields
class StringConstExpr extends Expr {
	var value:String;
	var tag:Bool;

	public function new(value:String, tag:Bool) {
		super();
		this.value = value;
		this.tag = tag;
	}
}

@:publicFields
class ConstantExpr extends Expr {
	var name:Token;

	public function new(name:Token) {
		super();
		this.name = name;
	}
}

@:publicFields
class AssignExpr extends Expr {
	var varExpr:VarExpr;
	var expr:Expr;

	public function new(varExpr:VarExpr, expr:Expr) {
		super();
		this.varExpr = varExpr;
		this.expr = expr;
	}
}

@:publicFields
class AssignOpExpr extends Expr {
	var varExpr:VarExpr;
	var expr:Expr;
	var op:Token;

	public function new(varExpr:VarExpr, expr:Expr, op:Token) {
		super();
		this.varExpr = varExpr;
		this.expr = expr;
		this.op = op;
	}
}

@:publicFields
class FuncCallExpr extends Expr {
	var name:Token;
	var namespace:Token;
	var args:Array<Expr>;

	public function new(name:Token, namespace:Token, args:Array<Expr>) {
		super();
		this.name = name;
		this.namespace = namespace;
		this.args = args;
	}
}

@:publicFields
class SlotAccessExpr extends Expr {
	var objectExpr:Expr;
	var arrayExpr:Array<Expr>;
	var slotName:Token;

	public function new(objectExpr:Expr, arrayExpr:Array<Expr>, slotName:Token) {
		super();
		this.objectExpr = objectExpr;
		this.arrayExpr = arrayExpr;
		this.slotName = slotName;
	}
}

@:publicFields
class SlotAssignExpr extends Expr {
	var objectExpr:Expr;
	var arrayExpr:Array<Expr>;
	var slotName:Token;
	var expr:Expr;

	public function new(objectExpr:Expr, arrayExpr:Array<Expr>, slotName:Token, expr:Expr) {
		super();
		this.objectExpr = objectExpr;
		this.arrayExpr = arrayExpr;
		this.slotName = slotName;
		this.expr = expr;
	}
}

@:publicFields
class SlotAssignOpExpr extends Expr {
	var objectExpr:Expr;
	var arrayExpr:Array<Expr>;
	var slotName:Token;
	var expr:Expr;
	var op:Token;

	public function new(objectExpr:Expr, arrayExpr:Array<Expr>, slotName:Token, expr:Expr, op:Token) {
		super();
		this.objectExpr = objectExpr;
		this.arrayExpr = arrayExpr;
		this.slotName = slotName;
		this.expr = expr;
		this.op = op;
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

	public function new(className:Expr, parentObject:Token, objectNameExpr:Expr, args:Array<Expr>, slotDecls:Array<SlotAssignExpr>,
			subObjects:Array<ObjectDeclExpr>) {
		super();
		this.className = className;
		this.parentObject = parentObject;
		this.objectNameExpr = objectNameExpr;
		this.args = args;
		this.slotDecls = slotDecls;
		this.subObjects = subObjects;
	}
}

@:publicFields
class FunctionDeclStmt extends Stmt {
	var functionName:Token;
	var packageName:Token;
	var args:Array<VarExpr>;
	var stmts:Array<Stmt>;
	var namespace:Token;

	public function new(functionName:Token, args:Array<VarExpr>, stmts:Array<Stmt>, namespace:Token) {
		this.functionName = functionName;
		this.args = args;
		this.stmts = stmts;
		this.namespace = namespace;
	}
}
