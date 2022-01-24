import sys.io.File;
import expr.Expr.Stmt;
import expr.Expr.BreakStmt;
import expr.Expr.ContinueStmt;
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

@:publicFields
class VarCollector implements IASTVisitor {
	var globalVars:Array<String> = [];
	var localVars:Map<FunctionDeclStmt, Array<String>> = [];

	var currentFunction:FunctionDeclStmt = null;

	static var reservedKwds = [
		"break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete", "do", "else", "enum", "export", "extends", "false",
		"finally", "for", "function", "if", "import", "in", "instanceof", "new", "null", "return", "super", "switch", "this", "throw", "true", "try",
		"typeof", "var", "void", "while", "with", "as", "implements", "interface", "let", "package", "private", "protected", "public", "static", "yield",
		"any", "boolean", "constructor", "declare", "get", "module", "require", "number", "set", "string", "symbol", "type", "from", "of"
	];

	public function new() {}

	public static function mangleName(name:String) {
		var ret = name;
		for (res in reservedKwds) {
			if (ret == res) {
				ret = StringTools.replace(ret, res, "_" + res);
			}
		}
		ret = StringTools.replace(ret, "::", "_");
		return ret;
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

	public function visitFloatBinaryExpr(expr:FloatBinaryExpr) {}

	public function visitIntBinaryExpr(expr:IntBinaryExpr) {}

	public function visitStrEqExpr(expr:StrEqExpr) {}

	public function visitStrCatExpr(expr:StrCatExpr) {}

	public function visitCommatCatExpr(expr:CommaCatExpr) {}

	public function visitConditionalExpr(expr:ConditionalExpr) {}

	public function visitIntUnaryExpr(expr:IntUnaryExpr) {}

	public function visitFloatUnaryExpr(expr:FloatUnaryExpr) {}

	public function visitVarExpr(expr:VarExpr) {
		if (expr.type == Global) {
			var n = mangleName(expr.name.literal);
			if (!this.globalVars.contains(n))
				this.globalVars.push(n);
		} else if (expr.type == Local) {
			if (this.localVars.exists(this.currentFunction)) {
				var n = mangleName(expr.name.literal);
				if (!this.localVars[this.currentFunction].contains(n))
					this.localVars[this.currentFunction].push(n);
			} else {
				this.localVars[this.currentFunction] = [mangleName(expr.name.literal)];
			}
		}
	}

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

	public function visitFunctionDeclStmt(stmt:FunctionDeclStmt) {
		currentFunction = stmt;
	}
}

class JSGenerator {
	var indent = 0;

	var stmts:Array<Stmt>;

	var builder:StringBuf = new StringBuf();

	var varCollector:VarCollector = new VarCollector();

	public function new(stmts:Array<Stmt>) {
		this.stmts = stmts;
	}

	public function generate() {
		var lib = File.getContent("tscriptlib.js");
		builder.add(lib);
		for (stmt in stmts) {
			stmt.visitStmt(varCollector);
			if (varCollector.currentFunction != null) {
				varCollector.currentFunction = null;
			}
		}
		for (global in varCollector.globalVars) {
			builder.add('let global_${global} = new TorqueVariable();\n');
		}

		for (stmt in stmts) {
			builder.add(printStmt(stmt));
		}
		return builder.toString();
	}

	function printStmt(stmt:Stmt) {
		if (Std.isOfType(stmt, BreakStmt)) {
			return println("break;");
		} else if (Std.isOfType(stmt, ContinueStmt)) {
			return println("continue;");
		} else if (Std.downcast(stmt, Expr) != null) {
			return println(printExpr(cast stmt, ReqNone) + ';');
		} else if (Std.isOfType(stmt, ReturnStmt)) {
			return printReturnStmt(cast stmt);
		} else if (Std.isOfType(stmt, IfStmt)) {
			return printIfStmt(cast stmt);
		} else if (Std.isOfType(stmt, LoopStmt)) {
			return printLoopStmt(cast stmt);
		} else if (Std.isOfType(stmt, FunctionDeclStmt)) {
			return printFunctionDeclStmt(cast stmt);
		} else
			return "";
	}

	function printReturnStmt(returnStmt:ReturnStmt) {
		if (returnStmt.expr != null) {
			var expr = printExpr(returnStmt.expr, ReqString);
			return println("return " + expr + ";");
		} else {
			return println("return;");
		}
	}

	function printIfStmt(ifStmt:IfStmt) {
		var ret = "";
		ret += println("if ("
			+ (ifStmt.condition.getPrefferredType() == ReqInt ? printExpr(ifStmt.condition, ReqInt) : printExpr(ifStmt.condition, ReqFloat))
			+ ") {");
		indent++;
		for (stmt in ifStmt.body) {
			ret += printStmt(stmt);
		}
		indent--;
		if (ifStmt.elseBlock != null) {
			ret += println("} else {");
			indent++;
			for (stmt in ifStmt.elseBlock) {
				ret += printStmt(stmt);
			}
			indent--;
		}
		ret += println("}");
		return ret;
	}

	function printLoopStmt(loopStmt:LoopStmt) {
		var ret = "";
		if (loopStmt.init != null) {
			ret += println(printExpr(loopStmt.init, ReqNone) + ';');
		}
		ret += println("while ("
			+ (loopStmt.condition.getPrefferredType() == ReqInt ? printExpr(loopStmt.condition, ReqInt) : printExpr(loopStmt.condition, ReqFloat))
			+ ") {");
		indent++;
		for (stmt in loopStmt.body) {
			ret += printStmt(stmt);
		}
		if (loopStmt.end != null)
			ret += println(printExpr(loopStmt.end, ReqNone) + ';');
		indent--;
		ret += println("}");
		return ret;
	}

	function printFunctionDeclStmt(functionDeclStmt:FunctionDeclStmt) {
		var fnameStr = '${functionDeclStmt.namespace != null ? cast(functionDeclStmt.namespace.literal, String) : ""}_${functionDeclStmt.functionName.literal}_${functionDeclStmt.packageName != null ? cast(functionDeclStmt.packageName.literal, String) : ""}';
		var declStr = println('function ${fnameStr}(args) {');
		indent++;
		var bodyStr = "";
		var addedVars = [];
		for (i in 0...functionDeclStmt.args.length) {
			var param = functionDeclStmt.args[i];
			var vname = VarCollector.mangleName(param.name.literal);
			bodyStr += println('let ${vname} = args[${i}];');
			addedVars.push(vname);
		}
		if (varCollector.localVars.exists(functionDeclStmt)) {
			for (localVar in varCollector.localVars[functionDeclStmt]) {
				if (!addedVars.contains(localVar)) {
					bodyStr += println('let ${localVar} = new TorqueVariable();');
				}
			}
		}
		for (stmt in functionDeclStmt.stmts) {
			bodyStr += printStmt(stmt);
		}
		indent--;
		declStr += bodyStr + println('}');
		declStr += println('addConsoleFunction(${fnameStr},\'${functionDeclStmt.functionName.literal}\',\'${functionDeclStmt.namespace != null ? cast(functionDeclStmt.namespace.literal, String) : ""}\', \'${functionDeclStmt.packageName != null ? cast(functionDeclStmt.packageName.literal, String) : ""}\');');
		return declStr;
	}

	function printExpr(expr:Expr, type:TypeReq) {
		if (Std.isOfType(expr, ParenthesisExpr)) {
			return printParenthesisExpr(cast expr, type);
		} else if (Std.isOfType(expr, ConditionalExpr)) {
			return printConditionalExpr(cast expr, type);
		} else if (Std.isOfType(expr, StrEqExpr)) {
			return printStrEqExpr(cast expr, type);
		} else if (Std.isOfType(expr, StrCatExpr)) {
			return printStrCatExpr(cast expr, type);
		} else if (Std.isOfType(expr, CommaCatExpr)) {
			return printCommaCatExpr(cast expr, type);
		} else if (Std.isOfType(expr, IntBinaryExpr)) {
			return printIntBinaryExpr(cast expr, type);
		} else if (Std.isOfType(expr, FloatBinaryExpr)) {
			return printFloatBinaryExpr(cast expr, type);
		} else if (Std.isOfType(expr, IntUnaryExpr)) {
			return printIntUnaryExpr(cast expr, type);
		} else if (Std.isOfType(expr, FloatUnaryExpr)) {
			return printFloatUnaryExpr(cast expr, type);
		} else if (Std.isOfType(expr, VarExpr)) {
			return printVarExpr(cast expr, type);
		} else if (Std.isOfType(expr, IntExpr)) {
			return printIntExpr(cast expr, type);
		} else if (Std.isOfType(expr, FloatExpr)) {
			return printFloatExpr(cast expr, type);
		} else if (Std.isOfType(expr, StringConstExpr)) {
			return printStringConstExpr(cast expr, type);
		} else if (Std.isOfType(expr, ConstantExpr)) {
			return printConstantExpr(cast expr, type);
		} else if (Std.isOfType(expr, AssignExpr)) {
			return printAssignExpr(cast expr, type);
		} else if (Std.isOfType(expr, AssignOpExpr)) {
			return printAssignOpExpr(cast expr, type);
		} else if (Std.isOfType(expr, FuncCallExpr)) {
			return printFuncCallExpr(cast expr, type);
		} else if (Std.isOfType(expr, SlotAccessExpr)) {
			return printSlotAccessExpr(cast expr, type);
		} else if (Std.isOfType(expr, SlotAssignExpr)) {
			return printSlotAssignExpr(cast expr, type);
		} else if (Std.isOfType(expr, SlotAssignOpExpr)) {
			return printSlotAssignOpExpr(cast expr, type);
		} else if (Std.isOfType(expr, ObjectDeclExpr)) {
			return printObjectDeclExpr(cast expr, type);
		} else
			return "";
	}

	function printParenthesisExpr(parenthesisExpr:ParenthesisExpr, type:TypeReq) {
		return "(" + printExpr(parenthesisExpr.expr, type) + ")";
	}

	function printConditionalExpr(conditionalExpr:ConditionalExpr, type:TypeReq) {
		return (conditionalExpr.condition.getPrefferredType() == ReqInt ? printExpr(conditionalExpr.condition,
			ReqInt) : printExpr(conditionalExpr.condition, ReqFloat))
			+ " ? "
			+ printExpr(conditionalExpr.trueExpr, type)
			+ " : "
			+ printExpr(conditionalExpr.falseExpr, type);
	}

	function printStrEqExpr(strEqExpr:StrEqExpr, type:TypeReq) {
		return conversionOp(ReqInt, type,
			printExpr(strEqExpr.left, ReqString) + (strEqExpr.op.type == StringEquals ? " == " : " != ") + printExpr(strEqExpr.right, ReqString));
	}

	function printStrCatExpr(strCatExpr:StrCatExpr, type:TypeReq) {
		var catExpr = switch (strCatExpr.op.type) {
			case TokenType.Concat:
				'';
			case TokenType.SpaceConcat:
				'\' \' + ';
			case TokenType.TabConcat:
				'\'\\t\' + ';
			case TokenType.NewlineConcat:
				'\'\\n\' + ';

			case _:
				'';
		}
		return conversionOp(ReqString, type, printExpr(strCatExpr.left, ReqString) + ' + ' + catExpr + printExpr(strCatExpr.right, ReqString));
	}

	function printCommaCatExpr(commaCatExpr:CommaCatExpr, type:TypeReq) {
		return conversionOp(ReqString, type, printExpr(commaCatExpr.left, ReqString) + ' + \'_\' + ' + printExpr(commaCatExpr.right, ReqString));
	}

	function printIntBinaryExpr(intBinaryExpr:IntBinaryExpr, type:TypeReq) {
		intBinaryExpr.getSubTypeOperand();
		return conversionOp(ReqInt, type,
			printExpr(intBinaryExpr.left, intBinaryExpr.subType)
			+ ' '
			+ intBinaryExpr.op.lexeme
			+ ' '
			+ printExpr(intBinaryExpr.right, intBinaryExpr.subType));
	}

	function printFloatBinaryExpr(floatBinaryExpr:FloatBinaryExpr, type:TypeReq) {
		return conversionOp(ReqFloat, type,
			printExpr(floatBinaryExpr.left, ReqFloat)
			+ ' '
			+ floatBinaryExpr.op.lexeme
			+ ' '
			+ printExpr(floatBinaryExpr.right, ReqFloat));
	}

	function printIntUnaryExpr(intUnaryExpr:IntUnaryExpr, type:TypeReq) {
		var prefType = intUnaryExpr.expr.getPrefferredType();
		switch (intUnaryExpr.op.type) {
			case Not:
				return conversionOp(ReqInt, type, '!' + (prefType == ReqInt ? printExpr(intUnaryExpr.expr, ReqInt) : printExpr(intUnaryExpr.expr, ReqFloat)));
			case Tilde:
				return conversionOp(ReqInt, type, '~' + (prefType == ReqInt ? printExpr(intUnaryExpr.expr, ReqInt) : printExpr(intUnaryExpr.expr, ReqFloat)));
			case _:
				return ""; // shouldnt reach here
		}
	}

	function printFloatUnaryExpr(floatUnaryExpr:FloatUnaryExpr, type:TypeReq) {
		return conversionOp(ReqFloat, type, '-' + printExpr(floatUnaryExpr.expr, ReqFloat));
	}

	function printVarExpr(varExpr:VarExpr, type:TypeReq) {
		switch (varExpr.type) {
			case Global:
				if (varExpr.arrayIndex == null) {
					return switch (type) {
						case ReqInt:
							'global_' + VarCollector.mangleName(varExpr.name.literal) + '.getIntValue()';
						case ReqFloat:
							'global_' + VarCollector.mangleName(varExpr.name.literal) + '.getFloatValue()';
						case ReqString:
							'global_' + VarCollector.mangleName(varExpr.name.literal) + '.getStringValue()';
						case ReqNone:
							'global_' + VarCollector.mangleName(varExpr.name.literal);
					}
				} else {
					return switch (type) {
						case ReqInt:
							'global_'
							+ VarCollector.mangleName(varExpr.name.literal)
							+ '.resolveArray('
							+ printExpr(varExpr.arrayIndex, ReqString)
							+ ').getIntValue()';
						case ReqFloat:
							'global_'
							+ VarCollector.mangleName(varExpr.name.literal)
							+ '.resolveArray('
							+ printExpr(varExpr.arrayIndex, ReqString)
							+ ').getFloatValue()';
						case ReqString:
							'global_'
							+ VarCollector.mangleName(varExpr.name.literal)
							+ '.resolveArray('
							+ printExpr(varExpr.arrayIndex, ReqString)
							+ ').getStringValue()';
						case ReqNone:
							'global_' + VarCollector.mangleName(varExpr.name.literal) + '[' + printExpr(varExpr.arrayIndex, ReqString) + ']';
					}
				}

			case Local:
				if (varExpr.arrayIndex == null) {
					return switch (type) {
						case ReqInt:
							VarCollector.mangleName(varExpr.name.literal) + '.getIntValue()';
						case ReqFloat:
							VarCollector.mangleName(varExpr.name.literal) + '.getFloatValue()';
						case ReqString:
							VarCollector.mangleName(varExpr.name.literal) + '.getStringValue()';
						case ReqNone:
							VarCollector.mangleName(varExpr.name.literal);
					}
				} else {
					return switch (type) {
						case ReqInt:
							VarCollector.mangleName(varExpr.name.literal)
							+ '.resolveArray('
							+ printExpr(varExpr.arrayIndex, ReqString)
							+ ').getIntValue()';
						case ReqFloat:
							VarCollector.mangleName(varExpr.name.literal)
							+ '.resolveArray('
							+ printExpr(varExpr.arrayIndex, ReqString)
							+ ').getFloatValue()';
						case ReqString:
							VarCollector.mangleName(varExpr.name.literal)
							+ '.resolveArray('
							+ printExpr(varExpr.arrayIndex, ReqString)
							+ ').getStringValue()';
						case ReqNone:
							VarCollector.mangleName(varExpr.name.literal)
							+ '.resolveArray('
							+ printExpr(varExpr.arrayIndex, ReqString)
							+ ')';
					}
				}
		}
	}

	function printIntExpr(intExpr:IntExpr, type:TypeReq) {
		switch (type) {
			case ReqNone:
				return '${intExpr.value}';
			case ReqInt:
				return '${intExpr.value}';
			case ReqFloat:
				return '${intExpr.value}';
			case ReqString:
				return '\'${intExpr.value}\'';
		}
	}

	function printFloatExpr(floatExpr:FloatExpr, type:TypeReq) {
		switch (type) {
			case ReqNone:
				return '${floatExpr.value}';
			case ReqInt:
				return '${Std.int(floatExpr.value)}';
			case ReqFloat:
				return '${floatExpr.value}';
			case ReqString:
				return '\'${floatExpr.value}\'';
		}
	}

	function printStringConstExpr(stringConstExpr:StringConstExpr, type:TypeReq) {
		switch (type) {
			case ReqNone:
				return '\'${stringConstExpr.value}\'';
			case ReqInt:
				var intValue = Std.parseInt(stringConstExpr.value);
				if (intValue == null)
					return '0';
				return '${intValue}';
			case ReqFloat:
				var floatValue = Std.parseFloat(stringConstExpr.value);
				if (Math.isNaN(floatValue))
					return '0';
				return '${floatValue}';
			case ReqString:
				return '\'${Scanner.escape(stringConstExpr.value)}\'';
		}
	}

	function printConstantExpr(constantExpr:ConstantExpr, type:TypeReq) {
		switch (type) {
			case ReqNone:
				return 'resolveIdent(\'' + constantExpr.name.literal + '\')';
			case ReqInt:
				return '${Std.int(Compiler.stringToNumber(constantExpr.name.literal))}';
			case ReqFloat:
				return '${Compiler.stringToNumber(constantExpr.name.literal)}';
			case ReqString:
				return '\'' + Scanner.escape(constantExpr.name.literal) + '\'';
		}
	}

	function printAssignExpr(assignExpr:AssignExpr, type:TypeReq) {
		var varStr = switch (assignExpr.varExpr.type) {
			case Global:
				if (assignExpr.varExpr.arrayIndex == null) {
					'global_' + VarCollector.mangleName(assignExpr.varExpr.name.literal) + '.';
				} else {'global_'
					+ VarCollector.mangleName(assignExpr.varExpr.name.literal)
					+ '.resolveArray('
					+ printExpr(assignExpr.varExpr.arrayIndex, ReqString)
					+ ').';
				}

			case Local:
				if (assignExpr.varExpr.arrayIndex == null) {
					VarCollector.mangleName(assignExpr.varExpr.name.literal) + '.';
				} else {VarCollector.mangleName(assignExpr.varExpr.name.literal)
					+ '.resolveArray('
					+ printExpr(assignExpr.varExpr.arrayIndex, ReqString)
					+ ').';
				}
		}
		varStr += switch (assignExpr.expr.getPrefferredType()) {
			case ReqInt:
				'setIntValue(' + printExpr(assignExpr.expr, ReqInt) + ')';
			case ReqFloat:
				'setFloatValue(' + printExpr(assignExpr.expr, ReqFloat) + ')';
			case ReqString:
				'setStringValue(' + printExpr(assignExpr.expr, ReqString) + ')';

			case ReqNone:
				'setStringValue(' + printExpr(assignExpr.expr, ReqString) + ')';
		}

		varStr = switch (type) {
			case ReqNone:
				varStr;

			case ReqInt | ReqFloat | ReqString:
				'(() => {' + varStr + '; return ' + printVarExpr(assignExpr.varExpr, type) + '; })()';
		}

		return varStr;
	}

	function printAssignOpExpr(assignOpExpr:AssignOpExpr, type:TypeReq) {
		assignOpExpr.getAssignOpTypeOp();
		var assignValue = printVarExpr(assignOpExpr.varExpr, assignOpExpr.subType)
			+ ' '
			+ assignOpExpr.op.lexeme.substr(0, assignOpExpr.op.lexeme.length - 1)
			+ ' '
			+ printExpr(assignOpExpr.expr, assignOpExpr.subType);

		var varStr = switch (assignOpExpr.varExpr.type) {
			case Global:
				if (assignOpExpr.varExpr.arrayIndex == null) {
					'global_' + VarCollector.mangleName(assignOpExpr.varExpr.name.literal) + '.';
				} else {'global_'
					+ VarCollector.mangleName(assignOpExpr.varExpr.name.literal)
					+ '.resolveArray('
					+ printExpr(assignOpExpr.varExpr.arrayIndex, ReqString)
					+ ').';
				}

			case Local:
				if (assignOpExpr.varExpr.arrayIndex == null) {
					VarCollector.mangleName(assignOpExpr.varExpr.name.literal) + '.';
				} else {VarCollector.mangleName(assignOpExpr.varExpr.name.literal)
					+ '.resolveArray('
					+ printExpr(assignOpExpr.varExpr.arrayIndex, ReqString)
					+ ').';
				}
		}
		varStr += switch (assignOpExpr.expr.getPrefferredType()) {
			case ReqInt:
				'setIntValue(' + assignValue + ')';
			case ReqFloat:
				'setFloatValue(' + assignValue + ')';
			case ReqString:
				'setStringValue(' + assignValue + ')';

			case _:
				return ""; // shouldnt reach here
		}

		varStr = switch (type) {
			case ReqNone:
				varStr;

			case ReqInt | ReqFloat | ReqString:
				'(() => {' + varStr + '; return ' + printVarExpr(assignOpExpr.varExpr, type) + '; })()';
		}

		return varStr;
	}

	function printFuncCallExpr(funcCallExpr:FuncCallExpr, type:TypeReq) {
		var paramStr = '[' + funcCallExpr.args.map(param -> printExpr(param, ReqString)).join(', ') + ']';
		var callTypeStr = switch (funcCallExpr.callType) {
			case FunctionCall:
				"FunctionCall";
			case MethodCall:
				"MethodCall";
			case ParentCall:
				"ParentCall";
		}
		var callStr = "callFunc("
			+ (funcCallExpr.namespace != null ? "'" + funcCallExpr.namespace.literal + "'" : '\'\'')
			+ ", \'"
			+ funcCallExpr.name.literal
			+ "\', "
			+ paramStr
			+ ", \'"
			+ callTypeStr
			+ "\')";

		callStr = switch (type) {
			case ReqNone | ReqString:
				callStr;
			case ReqInt:
				'parseInt(' + callStr + ')';
			case ReqFloat:
				'parseFloat(' + callStr + ')';
		}

		return callStr;
	}

	function printSlotAccessExpr(slotAccessExpr:SlotAccessExpr, type:TypeReq) {
		var objStr = printExpr(slotAccessExpr.objectExpr, ReqNone);
		var slotStr = "." + slotAccessExpr.slotName.literal;
		if (slotAccessExpr.arrayExpr != null) {
			slotStr += ".resolveArray(" + printExpr(slotAccessExpr.arrayExpr, ReqString) + ")";
		}
		var retStr = objStr + slotStr;
		retStr = switch (type) {
			case ReqNone:
				retStr;
			case ReqFloat:
				retStr + '.getFloatValue()';
			case ReqInt:
				retStr + '.getIntValue()';
			case ReqString:
				retStr + '.getStringValue()';
		}
		return retStr;
	}

	function printSlotAssignExpr(slotAssignExpr:SlotAssignExpr, type:TypeReq) {
		var objStr = printExpr(slotAssignExpr.objectExpr, ReqNone);
		var slotStr = "\'" + slotAssignExpr.slotName.literal + "\'";
		var slotArrayStr = slotAssignExpr.arrayExpr != null ? printExpr(slotAssignExpr.arrayExpr, ReqString) : 'null';
		var valueStr = printExpr(slotAssignExpr.expr, ReqString);
		var assignStr = 'slotAssign(${objStr}, ${slotStr}, ${slotArrayStr}, ${valueStr})';
		assignStr = switch (type) {
			case ReqNone:
				assignStr;
			case ReqFloat:
				'parseFloat(' + assignStr + ')';
			case ReqInt:
				'parseInt(' + assignStr + ')';
			case ReqString:
				'String(' + assignStr + ')';
		}
		return assignStr;
	}

	function printSlotAssignOpExpr(slotAssignOpExpr:SlotAssignOpExpr, type:TypeReq) {
		slotAssignOpExpr.getAssignOpTypeOp();
		var objStr = printExpr(slotAssignOpExpr.objectExpr, ReqNone);
		var slotStr = "\'" + slotAssignOpExpr.slotName.literal + "\'";
		var slotArrayStr = slotAssignOpExpr.arrayExpr != null ? printExpr(slotAssignOpExpr.arrayExpr, ReqString) : '';

		var slotRetrieveStr = "." + slotAssignOpExpr.slotName.literal;
		if (slotAssignOpExpr.arrayExpr != null) {
			slotRetrieveStr += ".resolveArray(" + printExpr(slotAssignOpExpr.arrayExpr, ReqString) + ")";
		}
		var valueStr = slotRetrieveStr + "." + switch (slotAssignOpExpr.subType) {
			case ReqNone | ReqString:
				"getStringValue() ";
			case ReqFloat:
				"getFloatValue() ";
			case ReqInt:
				"getIntValue() ";
		}

		valueStr += slotAssignOpExpr.op.lexeme.substr(0, slotAssignOpExpr.op.lexeme.length - 1)
			+ " "
			+ printExpr(slotAssignOpExpr.expr, slotAssignOpExpr.subType);

		var assignStr = 'slotAssign(${objStr}, ${slotStr}, ${slotArrayStr}, ${valueStr})';
		assignStr = switch (type) {
			case ReqNone:
				assignStr;
			case ReqFloat:
				'parseFloat(' + assignStr + ')';
			case ReqInt:
				'parseInt(' + assignStr + ')';
			case ReqString:
				'String(' + assignStr + ')';
		}
		return assignStr;
	}

	function printObjectDeclExpr(objDeclExpr:ObjectDeclExpr, type:TypeReq) {
		var retExpr = 'new TorqueObject(${printExpr(objDeclExpr.className, ReqString)}, ${printExpr(objDeclExpr.objectNameExpr, ReqString)}, ${objDeclExpr.structDecl}, ${objDeclExpr.parentObject != null ? "'" + objDeclExpr.parentObject.literal + "'" : null}, ';
		if (objDeclExpr.slotDecls.length != 0) {
			retExpr += "{\n";
			indent++;
			for (i in 0...objDeclExpr.slotDecls.length) {
				var slotdecl = objDeclExpr.slotDecls[i];
				var slotStr:String = slotdecl.slotName.literal;
				if (slotdecl.arrayExpr != null) {
					slotStr += ".resolveArray(" + printExpr(slotdecl.arrayExpr, ReqString) + ")";
				}
				slotStr += ": " + printExpr(slotdecl.expr, ReqNone);
				retExpr += println(slotStr + (i < objDeclExpr.slotDecls.length - 1 ? "," : ""));
			}
			indent--;
			for (i in 0...indent) {
				retExpr += "\t";
			}
			retExpr += print("}, ");
		} else {
			retExpr += "{}, ";
		}
		if (objDeclExpr.subObjects.length != 0) {
			retExpr += "[\n";
			indent++;
			for (i in 0...objDeclExpr.subObjects.length) {
				var subObj = objDeclExpr.subObjects[i];
				retExpr += println(printExpr(subObj, ReqNone) + (i < objDeclExpr.subObjects.length - 1 ? "," : ""));
			}
			indent--;
			for (i in 0...indent) {
				retExpr += "\t";
			}
			retExpr += print("])");
		} else {
			retExpr += "[])";
		}
		return retExpr;
	}

	function conversionOp(src:TypeReq, dest:TypeReq, exprStr:String) {
		return switch (src) {
			case ReqString:
				switch (dest) {
					case ReqInt:
						return 'parseInt(' + exprStr + ')';
					case ReqFloat:
						return 'parseFloat(' + exprStr + ')';
					case ReqNone:
						return '(() => { ${exprStr}; return ""; })()';
					default:
						return exprStr;
				}

			case ReqFloat:
				switch (dest) {
					case ReqInt:
						return 'Math.round(' + exprStr + ')';
					case ReqString:
						return 'String(' + exprStr + ')';
					case ReqNone:
						return '(() => { ${exprStr}; return 0.0; })()';
					default:
						return exprStr;
				}

			case ReqInt:
				switch (dest) {
					case ReqString:
						return 'String(' + exprStr + ')';
					case ReqFloat:
						return exprStr;
					case ReqNone:
						return '(() => { ${exprStr}; return 0; })()';
					default:
						return exprStr;
				}

			default:
				return exprStr;
		}
	}

	function print(str:String) {
		return str;
	}

	function println(str:String) {
		var indentStr = "";
		for (i in 0...indent)
			indentStr += "    ";
		return indentStr + str + "\n";
	}
}
