package;

import haxe.display.Display.Package;
import haxe.ds.GenericStack;
import expr.Expr;
import haxe.Exception;

class Parser {
	var tokens:Array<Token>;

	var current = 0;

	var positionStack:GenericStack<Int>;

	public function new(tokens:Array<Token>) {
		this.tokens = tokens;
		this.positionStack = new GenericStack();
	}

	public function parse() {
		return program();
	}

	function isAtEnd() {
		return current >= tokens.length;
	}

	function peek() {
		return tokens[current];
	}

	function previous() {
		return tokens[current - 1];
	}

	function advance() {
		if (!isAtEnd())
			current++;
		return tokens[current - 1];
	}

	function program() {
		var statements:Array<Expr> = [];

		if (peek().type != TokenType.Eof) {
			while (!isAtEnd()) {
				var stmt = statement();
				if (stmt == null)
					throw new Exception("Failed to parse statement");
				statements.push(stmt);
			}
		}
		return statements;
	}

	function statement() {
		var stmt:Expr = functionDeclaration();
		if (stmt == null)
			stmt = packageDeclaration();
		if (stmt == null)
			stmt = expressionStatement();
		return stmt;
	}

	function functionDeclaration():FunctionDeclaration {
		if (match([TokenType.Function])) {
			advance(); // Consume `function`
			var l1 = label();
			if (l1 == null) {
				throw new Exception("Expected function name");
			}

			if (match([TokenType.LParen])) {
				advance(); // Consume `(`
				var parameters = functionDeclarationParameters();
				consume(TokenType.RParen, "Expected ) after function declaration parameters");
				consume(TokenType.LBracket, "Expected { after function declaration");

				var exprs = [];

				var expr = expressionStatement();
				while (expr != null) {
					exprs.push(expr);
					expr = expressionStatement();
				}

				consume(TokenType.RBracket, "Expected } after function body");

				var functionDeclarationExpr = new FunctionDeclaration(null, l1, parameters, exprs);
				return functionDeclarationExpr;
			} else if (match([TokenType.DoubleColon])) {
				advance(); // Consume the colons
				var sublabel = label();
				if (sublabel == null) {
					throw new Exception("Expected label after ::");
				}

				if (match([TokenType.LParen])) {
					advance(); // Consume `(`
					var parameters = functionDeclarationParameters();
					consume(TokenType.RParen, "Expected ) after function declaration parameters");
					consume(TokenType.LBracket, "Expected { after function declaration");

					var exprs = [];
					var expr = expressionStatement();
					while (expr != null) {
						exprs.push(expr);
						expr = expressionStatement();
					}

					consume(TokenType.RBracket, "Expected } after function body");

					var functionDeclarationExpr = new FunctionDeclaration(l1, sublabel, parameters, exprs);
					return functionDeclarationExpr;
				} else {
					throw new Exception("Expected function declaration");
				}
			} else {
				throw new Exception("Expected function signature");
			}
		} else {
			return null;
		}
	}

	function functionDeclarationParameters():Null<FunctionDeclarationParameters> {
		var firstparam = localVariable();
		if (firstparam == null)
			return null;
		else {
			var params = [firstparam];
			while (match([TokenType.Comma])) {
				advance(); // Consume `,`
				var param = localVariable();
				if (param == null)
					throw new Exception("Expected parameter name");
				params.push(param);
			}
			return new FunctionDeclarationParameters(params);
		}
	}

	function packageDeclaration():PackageDeclaration {
		if (match([TokenType.Package])) {
			advance();
			var l1 = label();
			if (l1 == null)
				throw new Exception("Expected package name");

			consume(TokenType.LBracket, "Expected { after package declaration");

			var fnDeclrs = [];
			var fnDeclr = functionDeclaration();
			if (fnDeclr == null)
				throw new Exception("Expected atleast one function in package");
			fnDeclrs.push(fnDeclr);
			do {
				fnDeclr = functionDeclaration();
				if (fnDeclr != null)
					fnDeclrs.push(fnDeclr);
			} while (fnDeclr != null);

			consume(TokenType.RBracket, "Expected } after package body");
			consume(TokenType.Semicolon, "Expected ; after package body");

			var packageDeclr = new PackageDeclaration(l1, fnDeclrs);
			return packageDeclr;
		} else
			return null;
	}

	function expressionStatement():ExprStatement {
		var expr:ExprStatement = primaryExpression();
		if (expr != null)
			consume(TokenType.Semicolon, "Expected ; after expression");
		if (expr == null)
			expr = whileControl();
		if (expr == null)
			expr = forControl();
		if (expr == null)
			expr = ifControl();
		if (expr == null)
			expr = switchControl();
		if (expr == null) {
			expr = continueControl();
			if (expr != null)
				consume(TokenType.Semicolon, "Expected ; after expression");
		}
		if (expr == null) {
			expr = breakControl();
			if (expr != null)
				consume(TokenType.Semicolon, "Expected ; after expression");
		}
		if (expr == null) {
			expr = returnControl();
			if (expr != null)
				consume(TokenType.Semicolon, "Expected ; after expression");
		}
		return expr;
	}

	function returnControl():ReturnControl {
		if (match([TokenType.Return])) {
			advance();
			var expr = primaryExpressionOrExpression();
			return new ReturnControl(expr);
		} else {
			return null;
		}
	}

	function primaryExpression():ExprStatement {
		var curpos = current;
		var expr:ExprStatement = primaryChain();
		if (expr == null) {
			current = curpos;
			var expr2 = assignableChain();

			if (expr2 == null) {
				current = curpos;
			} else {
				var nextTok = peek();
				switch (nextTok.type) {
					case Assign, PlusAssign, MinusAssign, MultiplyAssign, DivideAssign, OrAssign, ModulusAssign, AndAssign:
						advance();
						var rhs = primaryExpressionOrExpression();
						return new AssignmentExpr(nextTok, expr2, rhs);

					case PlusPlus, MinusMinus:
						advance();
						if (match([
							TokenType.BitwiseXor, TokenType.BitwiseOr, TokenType.BitwiseAnd, TokenType.Modulus, TokenType.Multiply, TokenType.Divide,
							TokenType.Plus, TokenType.Minus, TokenType.QuestionMark, TokenType.LessThan, TokenType.GreaterThan, TokenType.GreaterThanEqual,
							TokenType.LessThanEqual, TokenType.LeftBitShift, TokenType.RightBitShift, TokenType.LogicalAnd, TokenType.LogicalOr,
							TokenType.Equal, TokenType.NotEqual, TokenType.StringEquals, TokenType.StringNotEquals, TokenType.Concat, TokenType.SpaceConcat,
							TokenType.TabConcat, TokenType.NewlineConcat, TokenType.Dot
						])) {
							current = curpos;
							expr = null;
						} else
							return new PostfixExpr(nextTok, expr2);

					default:
						current = curpos;
				}
			}
		}
		if (expr == null) {
			expr = objectDeclaration();
		}
		if (expr == null) {
			expr = datablockDeclaration();
		}

		return expr;
	}

	function primaryChain():ExprStatement {
		var curPos = current;

		var l1 = label();
		if (l1 != null) {
			if (match([TokenType.LParen])) {
				advance();
				var exprs = [];
				if (!match([TokenType.RParen])) {
					var expr = primaryExpressionOrExpression();
					while (expr != null) {
						exprs.push(expr);
						if (match([TokenType.Comma])) {
							advance();
							expr = primaryExpressionOrExpression();
						} else {
							expr = null;
						}
					}
				}
				consume(TokenType.RParen, "Expected ) after call");

				var fncall = new FunctionCall(null, l1, exprs);

				if (match([
					TokenType.BitwiseXor, TokenType.BitwiseOr, TokenType.BitwiseAnd, TokenType.Modulus, TokenType.Multiply, TokenType.Divide, TokenType.Plus,
					TokenType.Minus, TokenType.QuestionMark, TokenType.LessThan, TokenType.GreaterThan, TokenType.GreaterThanEqual, TokenType.LessThanEqual,
					TokenType.LeftBitShift, TokenType.RightBitShift, TokenType.LogicalAnd, TokenType.LogicalOr, TokenType.Equal, TokenType.NotEqual,
					TokenType.StringEquals, TokenType.StringNotEquals, TokenType.Concat, TokenType.SpaceConcat, TokenType.TabConcat, TokenType.NewlineConcat,
					TokenType.Dot
				])) {
					current = curPos;
				} else
					return fncall;
			} else if (match([TokenType.DoubleColon])) {
				advance();
				var l2 = label();
				if (l2 == null)
					throw new Exception("Expected function name");
				if (match([TokenType.LParen])) {
					advance();
					var exprs = [];
					if (!match([TokenType.RParen])) {
						var expr = primaryExpressionOrExpression();
						while (expr != null) {
							exprs.push(expr);
							if (match([TokenType.Comma])) {
								advance();
								expr = primaryExpressionOrExpression();
							} else {
								expr = null;
							}
						}
					}
					consume(TokenType.RParen, "Expected ) after call");

					var fncall = new FunctionCall(l1, l2, exprs);

					if (match([
						TokenType.BitwiseXor, TokenType.BitwiseOr, TokenType.BitwiseAnd, TokenType.Modulus, TokenType.Multiply, TokenType.Divide,
						TokenType.Plus, TokenType.Minus, TokenType.QuestionMark, TokenType.LessThan, TokenType.GreaterThan, TokenType.GreaterThanEqual,
						TokenType.LessThanEqual, TokenType.LeftBitShift, TokenType.RightBitShift, TokenType.LogicalAnd, TokenType.LogicalOr, TokenType.Equal,
						TokenType.NotEqual, TokenType.StringEquals, TokenType.StringNotEquals, TokenType.Concat, TokenType.SpaceConcat, TokenType.TabConcat,
						TokenType.NewlineConcat, TokenType.Dot
					])) {
						current = curPos;
					} else
						return fncall;
				} else
					throw new Exception("Expected (");
			}
		}

		// Go back cause its not the function calls
		current = curPos;

		// Its the chain thing now
		var chStart = chainStart();

		if (match([TokenType.Dot])) {
			advance();
		} else {
			current = curPos;
			return null;
		}
		var chElements = chainElements();

		if (chElements == null) {
			// subfunctioncall
			var l2 = label();
			consume(TokenType.LParen, "Expected (");
			var exprs = [];
			if (!match([TokenType.RParen])) {
				var expr = primaryExpressionOrExpression();
				while (expr != null) {
					exprs.push(expr);
					if (match([TokenType.Comma])) {
						advance();
						expr = primaryExpressionOrExpression();
					} else {
						expr = null;
					}
				}
			}
			consume(TokenType.RParen, "Expected ) after call");
			return new MethodCall(new ChainExpr(chStart, chElements), new FunctionCall(null, l2, exprs));
		} else {
			if (match([TokenType.Dot])) {
				// subfunctioncall
				advance(); // Skip the dot
				var l2 = label();
				consume(TokenType.LParen, "Expected (");
				var exprs = [];
				if (!match([TokenType.RParen])) {
					var expr = primaryExpressionOrExpression();
					while (expr != null) {
						exprs.push(expr);
						if (match([TokenType.Comma])) {
							advance();
							expr = primaryExpressionOrExpression();
						} else {
							expr = null;
						}
					}
				}
				consume(TokenType.RParen, "Expected ) after call");
				return new MethodCall(chStart, new FunctionCall(null, l2, exprs));
			} else {
				if (Std.isOfType(chElements, FunctionCall)) {
					if (match([
						TokenType.BitwiseXor, TokenType.BitwiseOr, TokenType.BitwiseAnd, TokenType.Modulus, TokenType.Multiply, TokenType.Divide,
						TokenType.Plus, TokenType.Minus, TokenType.QuestionMark, TokenType.LessThan, TokenType.GreaterThan, TokenType.GreaterThanEqual,
						TokenType.LessThanEqual, TokenType.LeftBitShift, TokenType.RightBitShift, TokenType.LogicalAnd, TokenType.LogicalOr, TokenType.Equal,
						TokenType.NotEqual, TokenType.StringEquals, TokenType.StringNotEquals, TokenType.Concat, TokenType.SpaceConcat, TokenType.TabConcat,
						TokenType.NewlineConcat, TokenType.Comma
					])) {
						current = curPos;
						return null;
					}
					return new MethodCall(chStart, cast chElements);
				} else if (Std.isOfType(chElements, ChainExpr)) {
					var lastElemParent:ChainExpr = null;
					var lastElem:ChainExpr = cast chElements;
					while (Std.isOfType(lastElem.right, ChainExpr)) {
						lastElemParent = lastElem;
						lastElem = cast lastElem.right;
					}

					if (Std.isOfType(lastElem.right, FunctionCall)) {
						if (match([
							TokenType.BitwiseXor, TokenType.BitwiseOr, TokenType.BitwiseAnd, TokenType.Modulus, TokenType.Multiply, TokenType.Divide,
							TokenType.Plus, TokenType.Minus, TokenType.QuestionMark, TokenType.LessThan, TokenType.GreaterThan, TokenType.GreaterThanEqual,
							TokenType.LessThanEqual, TokenType.LeftBitShift, TokenType.RightBitShift, TokenType.LogicalAnd, TokenType.LogicalOr,
							TokenType.Equal, TokenType.NotEqual, TokenType.StringEquals, TokenType.StringNotEquals, TokenType.Concat, TokenType.SpaceConcat,
							TokenType.TabConcat, TokenType.NewlineConcat, TokenType.Comma
						])) {
							current = curPos;
							return null;
						}
						if (lastElemParent != null) {
							lastElemParent.right = lastElem.left;
						}
						return new MethodCall(new ChainExpr(chStart, chElements), cast lastElem.right);
					}
					return null;
				} else {
					current = curPos;
					return null;
				}
			}
		}
	}

	function chainStart():Expr {
		var curPos = current;
		if (match([TokenType.LParen])) {
			advance();
			var expr = primaryExpressionOrExpression();
			if (expr == null) {
				throw new Exception("Expected an expression after ( for chainStart");
			}
			consume(TokenType.RParen, "Expected ) after expression");
			if (match([TokenType.Dot]))
				return new ParenthesizedExpression(new ChainExpression(expr));
			else {
				current = curPos;
			}
		}

		var expr:Expr = localArray();
		if (expr == null)
			expr = globalArray();
		if (expr == null)
			expr = globalVariable();
		if (expr == null)
			expr = localVariable();
		if (expr == null) {
			var l1 = label();
			if (l1 == null) {
				expr = rvalue();

				return expr;
			}

			if (match([TokenType.LParen])) {
				advance();
				var exprs = [];
				var expr = primaryExpressionOrExpression();
				if (!match([TokenType.RParen])) {
					while (expr != null) {
						exprs.push(expr);
						if (match([TokenType.Comma])) {
							advance();
							expr = primaryExpressionOrExpression();
						} else {
							expr = null;
						}
					}
				}
				consume(TokenType.RParen, "Expected ) after call");

				var fncall = new FunctionCall(null, l1, exprs);
				return fncall;
			} else if (match([TokenType.DoubleColon])) {
				advance();
				var l2 = label();
				if (l2 == null)
					throw new Exception("Expected function name");
				if (match([TokenType.LParen])) {
					advance();
					var exprs = [];
					if (!match([TokenType.RParen])) {
						var expr = primaryExpressionOrExpression();
						while (expr != null) {
							exprs.push(expr);
							if (match([TokenType.Comma])) {
								advance();
								expr = primaryExpressionOrExpression();
							} else {
								expr = null;
							}
						}
					}
					consume(TokenType.RParen, "Expected ) after call");

					var fncall = new FunctionCall(l1, l2, exprs);
					return fncall;
				} else
					throw new Exception("Expected (");
			} else {
				return new FieldExpr(l1);
			}
		} else
			return expr;
	}

	function chainElements():Expr {
		if (match([TokenType.Label])) {
			var l1 = advance();
			if (match([TokenType.LeftSquareBracket])) {
				advance(); // consume [
				var exprs:Array<Expr> = [];
				var expr = expression();
				while (expr != null) {
					exprs.push(expr);
					if (match([TokenType.Comma])) {
						advance();
						expr = expression();
					} else {
						expr = null;
					}
				}
				consume(TokenType.RightSquareBracket, "Expected ] after call");
				var retexpr = new FieldArrayExpr(new Label(l1.literal), exprs);

				if (match([TokenType.Dot])) {
					advance();
					var elements = chainElements();
					if (elements == null)
						throw new Exception("Expected fields after period");
					return new ChainExpr(retexpr, elements);
				} else {
					return retexpr;
				}
			} else if (match([TokenType.LParen])) {
				advance(); // consume ()
				var exprs = [];
				if (!match([TokenType.RParen])) {
					var expr = primaryExpressionOrExpression();
					while (expr != null) {
						exprs.push(expr);
						if (match([TokenType.Comma])) {
							advance();
							expr = primaryExpressionOrExpression();
						} else {
							expr = null;
						}
					}
				}
				consume(TokenType.RParen, "Expected ) after call");

				var fncall = new FunctionCall(null, new Label(l1.literal), exprs);
				if (match([TokenType.Dot])) {
					advance();
					var elements = chainElements();
					if (elements == null)
						throw new Exception("Expected fields after period");
					return new ChainExpr(fncall, elements);
				} else {
					return fncall;
				}
			} else if (match([TokenType.Dot])) {
				advance(); // consume .
				var elements = chainElements();
				if (elements == null)
					throw new Exception("Expected fields after period");

				return new ChainExpr(new Label(l1.literal), elements);
			} else {
				return new Label(l1.literal);
			}
		} else {
			return null;
		}
	}

	function assignableChain():Expr {
		var curpos = current;
		var expr:Expr = localArray();
		if (expr == null)
			expr = globalArray();
		if (expr == null)
			expr = localVariable();
		if (expr == null)
			expr = globalVariable();
		if (expr == null) {
			var expr = chainStart();
			if (expr == null)
				return null;
		}
		if (match([TokenType.Dot])) {
			advance(); // Consume the dot

			var chElements = chainElements();
			if (chElements != null) {
				var l1 = new ChainExpr(expr, chElements);
				if (match([TokenType.Dot])) {
					var l2 = consume(TokenType.Label, "Expected field name");
					if (match([TokenType.LeftSquareBracket])) {
						var exprlist = [];
						var expriter = primaryExpressionOrExpression();
						while (expriter != null) {
							exprlist.push(expriter);
							if (match([TokenType.Comma])) {
								advance();
								expriter = primaryExpressionOrExpression();
							} else {
								expriter = null;
							}
						}
						consume(TokenType.RightSquareBracket, "Expected ] after call");
						return new ChainExpr(l1, new FieldArrayExpr(new Label(l2.literal), exprlist));
					} else {
						return new ChainExpr(l1, new Label(l2.literal));
					}
				} else {
					return l1;
				}
			} else {
				var l2 = consume(TokenType.Label, "Expected field name");
				if (match([TokenType.LeftSquareBracket])) {
					var exprlist = [];
					var expriter = primaryExpressionOrExpression();
					while (expriter != null) {
						exprlist.push(expriter);
						if (match([TokenType.Comma])) {
							advance();
							expriter = primaryExpressionOrExpression();
						} else {
							expriter = null;
						}
					}
					consume(TokenType.RightSquareBracket, "Expected ] after call");
					return new ChainExpr(expr, new FieldArrayExpr(new Label(l2.literal), exprlist));
				} else {
					return new ChainExpr(expr, new Label(l2.literal));
				}
			}
		} else {
			if (expr != null) {
				return expr;
			} else {
				current = curpos;
				return null;
			}
		}
	}

	function objectDeclaration():ObjectDeclaration {
		if (match([TokenType.New])) {
			advance(); // consume new
			var className:Expr;
			if (match([TokenType.LParen])) {
				advance();
				className = expression();
				consume(TokenType.RParen, "Expected ) after class name");
			} else {
				className = label();
			}
			if (className == null)
				throw new Exception("Expected class name");

			var objName:Expr = null;
			consume(TokenType.LParen, "Expected ( after new");
			objName = primaryExpressionOrExpression();
			var parentClassName:Expr = null;
			if (match([TokenType.Colon])) {
				advance(); // consume :
				parentClassName = primaryExpressionOrExpression();
			}
			consume(TokenType.RParen, "Expected ) after new");

			var fields = [];
			var objdeclrs = [];

			if (match([TokenType.LBracket])) {
				consume(TokenType.LBracket, "Expected { after new");

				var curfield = fieldAssign();
				while (curfield != null) {
					fields.push(curfield);
					curfield = fieldAssign();
				}

				var curobjdeclr = objectDeclaration();
				while (curobjdeclr != null) {
					consume(TokenType.Semicolon, "Expected ; after object declaration");
					objdeclrs.push(curobjdeclr);
					curobjdeclr = objectDeclaration();
				}

				consume(TokenType.RBracket, "Expected } after new");
			}

			return new ObjectDeclaration(className, objName, parentClassName, fields, objdeclrs);
		} else {
			return null;
		}
	}

	function datablockDeclaration():ExprStatement {
		if (match([TokenType.Datablock])) {
			advance(); // consume the datablock

			var l1 = label();
			if (l1 == null)
				throw new Exception("Expected a class type");
			consume(TokenType.LParen, "Expected (");
			var l2 = label();
			if (l2 == null)
				throw new Exception("Expected a datablock name");
			var baseshit:Label = null;
			if (match([TokenType.Colon])) {
				advance(); // consume the colon
				baseshit = label();
				if (baseshit == null)
					throw new Exception("Expected a base datablock");
			}

			consume(TokenType.RParen, "Expected )");

			consume(TokenType.LBracket, "Expected {");

			var fields = [];
			var f1 = fieldAssign();
			if (f1 == null)
				throw new Exception("Must have at least one field");
			while (f1 != null) {
				fields.push(f1);
				f1 = fieldAssign();
			}

			consume(TokenType.RBracket, "Expected }");

			return new DatablockDeclaration(l1, l2, baseshit, fields);
		} else {
			return null;
		}
	}

	function fieldAssign():FieldAssignmentExpr {
		if (match([
			TokenType.Label, TokenType.Package, TokenType.Return, TokenType.Break, TokenType.Continue, TokenType.While, TokenType.False, TokenType.True,
			TokenType.Function, TokenType.Else, TokenType.If, TokenType.Datablock, TokenType.Case, TokenType.SpaceConcat, TokenType.TabConcat,
			TokenType.NewlineConcat
		])) {
			var tok = advance();
			var l1 = new Label(tok.literal);
			var subscript:Array<Expr> = null;

			if (match([TokenType.LeftSquareBracket])) {
				advance(); // consume [
				var exprs = [];
				var expr = primaryExpressionOrExpression();
				while (expr != null) {
					exprs.push(expr);
					if (match([TokenType.Comma])) {
						advance();
						expr = primaryExpressionOrExpression();
					} else {
						expr = null;
					}
				}
				consume(TokenType.RightSquareBracket, "Expected ] after array call");
				subscript = exprs;
			}

			consume(TokenType.Assign, "Expected = after field name");
			var rhs = primaryExpressionOrExpression();
			consume(TokenType.Semicolon, "Expected ; after field assignment");

			var fieldexpr = new FieldAssignmentExpr(l1, subscript, rhs);
			return fieldexpr;
		} else {
			return null;
		}
	}

	function primaryExpressionOrExpression():Expr {
		var expr:Expr = primaryExpression();
		if (expr == null)
			expr = expression();
		return expr;
	}

	function forControl():ForControl {
		if (match([TokenType.For])) {
			advance();
			consume(TokenType.LParen, "Expected (");
			var exp1 = primaryExpressionOrExpression();
			consume(TokenType.Semicolon, "Expected ; after for condition");
			var exp2 = primaryExpressionOrExpression();
			consume(TokenType.Semicolon, "Expected ; after for condition");
			var exp3 = primaryExpressionOrExpression();
			consume(TokenType.RParen, "Expected ) after for condition");
			var block = controlStatements();

			var forControl = new ForControl(exp1, exp2, exp3, block);
			return forControl;
		} else {
			return null;
		}
	}

	function ifControl():IfControl {
		if (match([TokenType.If])) {
			advance(); // Consume the `if`

			consume(TokenType.LParen, "Expected (");

			var expr = primaryExpressionOrExpression();

			consume(TokenType.RParen, "Expected ) after if condition");

			var block = controlStatements();

			if (match([TokenType.Else])) {
				advance(); // Consume the `else`
				var elseBlock = controlStatements();
				var elseCtrl = new ElseControl(elseBlock);
				var ifControl = new IfControl(expr, block, elseCtrl);
				return ifControl;
			} else {
				var ifControl = new IfControl(expr, block, null);
				return ifControl;
			}
		} else {
			return null;
		}
	}

	function whileControl():WhileControl {
		if (match([TokenType.While])) {
			advance(); // Consume the `while`
			consume(TokenType.LParen, "Expected (");
			var expr = expression();
			if (expr == null)
				throw new Exception("Expected expression");
			consume(TokenType.RParen, "Expected ) after while condition");

			var block = controlStatements();

			var whileCtrl = new WhileControl(expr, block);
			return whileCtrl;
		} else {
			return null;
		}
	}

	function switchControl():SwitchControl {
		if (match([TokenType.Switch])) {
			advance(); // Consume the `switch`
			var isStringSwitch = false;
			if (match([TokenType.Dollar])) {
				isStringSwitch = true;
				advance();
			}
			consume(TokenType.LParen, "Expected (");
			var expr = primaryExpressionOrExpression();
			if (expr == null)
				throw new Exception("Expected expression");
			consume(TokenType.RParen, "Expected ) after while condition");

			consume(TokenType.LBracket, "Expected { after condition");

			var cases = [];
			var caseCtrl:CaseControl = caseControl();
			if (caseCtrl == null)
				throw new Exception("Expected atleast a single case in switch");
			cases.push(caseCtrl);
			do {
				caseCtrl = caseControl();
				if (caseCtrl != null)
					cases.push(caseCtrl);
			} while (caseCtrl != null);

			var defaultCtrl = defaultControl();

			consume(TokenType.RBracket, "Expected }");

			var switchCtrl = new SwitchControl(isStringSwitch, expr, cases, defaultCtrl);
			return switchCtrl;
		} else {
			return null;
		}
	}

	function caseControl():CaseControl {
		if (match([TokenType.Case])) {
			advance(); // Consume the `case`

			var exprs = [];

			var expr = expression();

			while (expr != null) {
				exprs.push(expr);
				if (match([TokenType.Or])) {
					advance();
					expr = expression();
				} else {
					expr = null;
				}
			}

			consume(TokenType.Colon, "Expected : after condition");

			var exprStmts = [];
			var stmt = expressionStatement();
			while (stmt != null) {
				exprStmts.push(stmt);
				stmt = expressionStatement();
			}

			return new CaseControl(exprs, exprStmts);
		} else {
			return null;
		}
	}

	function defaultControl():DefaultControl {
		if (match([TokenType.Default])) {
			advance(); // Consume the `default`
			consume(TokenType.Colon, "Expected : after default");

			var exprStmts = [];
			var stmt = expressionStatement();
			while (stmt != null) {
				exprStmts.push(stmt);
				stmt = expressionStatement();
			}

			return new DefaultControl(exprStmts);
		} else {
			return null;
		}
	}

	function continueControl():ContinueControl {
		if (match([TokenType.Continue])) {
			advance(); // Consume the `continue`
			return new ContinueControl();
		} else {
			return null;
		}
	}

	function breakControl():BreakControl {
		if (match([TokenType.Break])) {
			advance(); // Consume the `break`
			return new BreakControl();
		} else {
			return null;
		}
	}

	function controlStatements():Array<ExprStatement> {
		if (match([TokenType.LBracket])) {
			advance(); // Consume `{`
			var exprs:Array<ExprStatement> = [];
			var expr = expressionStatement();
			while (expr != null) {
				exprs.push(expr);
				expr = expressionStatement();
			}
			consume(TokenType.RBracket, "Expected } after control statements");
			return exprs;
		} else {
			var expr = expressionStatement();
			if (expr == null)
				return null;
			return [expr];
		}
	}

	function chain():Expr {
		var chStart = chainStart();
		if (chStart != null) {
			if (match([TokenType.Dot])) {
				advance(); // Consume the dot

				var chelements = chainElements();
				if (chelements == null)
					throw new Exception("Expected chain elements");

				return new ChainExpr(chStart, chelements);
			} else {
				return chStart;
			}
		} else {
			return null;
		}
	}

	function expression(recurse:Int = 0):Expression {
		// Do the precendence crap in this order of if conditions
		// parenthesis
		// string concat
		// equality compare
		// logical
		// bitshifts
		// relational
		// ternary
		// add/sub
		// mult/div/mod
		// bitwise
		// chain
		// unary

		// TODO FIX POSTFIX

		function primaryExp():Expression {
			var ch = chain();
			if (ch != null) {
				var chexp = new ChainExpression(ch);
				if (match([TokenType.PlusPlus, TokenType.MinusMinus])) {
					var postfix = advance();
					return new PostfixExpression(postfix, chexp);
				} else
					return chexp;
			} else {
				var rval = rvalue();
				if (rval != null)
					return new ValueExpression(rval);
				else {
					if (match([TokenType.Minus, TokenType.Not, TokenType.Tilde])) {
						var op = advance(); // Consume the unary operator
						var expr = expression();
						if (expr == null)
							throw new Exception("Expected expression after unary operator");
						if (match([TokenType.PlusPlus, TokenType.MinusMinus])) {
							var postfix = advance();
							return new UnaryExpression(new PostfixExpression(postfix, expr), op);
						} else
							return new UnaryExpression(expr, op);
					} else {
						if (match([TokenType.LParen])) {
							advance(); // Consume the `(`
							var ret = primaryExpressionOrExpression();
							consume(TokenType.RParen, "Expected ) after expression");
							var chexp = new ParenthesizedExpression(new ChainExpression(ret));
							if (match([TokenType.PlusPlus, TokenType.MinusMinus])) {
								var postfix = advance();
								return new PostfixExpression(postfix, chexp);
							} else
								return chexp;
						} else {
							return null;
						}
					}
				}
			}
		}

		function bitwiseExp():Expression {
			var lhs = primaryExp();
			if (match([TokenType.BitwiseAnd, TokenType.BitwiseOr, TokenType.BitwiseXor])) {
				var op = advance(); // Consume the bitwise operator
				var rhs = primaryExp();
				if (rhs == null)
					throw new Exception("Expected expression after bitwise operator");

				rhs = new BitshiftExpression(lhs, op, rhs);

				while (match([TokenType.BitwiseAnd, TokenType.BitwiseOr, TokenType.BitwiseXor])) {
					var op2 = advance(); // Consume the bitwise operator
					var rhs2 = primaryExp();
					if (rhs2 == null)
						throw new Exception("Expected expression after bitwise operator");

					rhs = new BitwiseExpression(rhs, op2, rhs2);
				}

				return rhs;
			} else {
				return lhs;
			}
		}

		function factorExp():Expression {
			var lhs = bitwiseExp();

			if (match([TokenType.Modulus, TokenType.Multiply, TokenType.Divide])) {
				var op = advance(); // Consume the operator
				var rhs = bitwiseExp();
				if (rhs == null)
					throw new Exception("Expected rhs after bitwise operator");

				rhs = new ArithmeticExpression(lhs, op, rhs);

				while (match([TokenType.Modulus, TokenType.Multiply, TokenType.Divide])) {
					var op2 = advance(); // Consume the operator
					var rhs2 = bitwiseExp();
					if (rhs2 == null)
						throw new Exception("Expected rhs after bitwise operator");

					rhs = new ArithmeticExpression(rhs, op2, rhs2);
				}

				return rhs;
			} else {
				return lhs;
			}
		}

		function termExp():Expression {
			var lhs = factorExp();

			if (match([TokenType.Plus, TokenType.Minus])) {
				var op = advance(); // Consume the plus/minus operator
				var rhs = termExp();
				if (rhs == null)
					throw new Exception("Expected expression after plus/minus operator");
				rhs = new ArithmeticExpression(lhs, op, rhs);

				while (match([TokenType.Plus, TokenType.Minus])) {
					var op2 = advance(); // Consume the plus/minus operator
					var rhs2 = termExp();
					if (rhs2 == null)
						throw new Exception("Expected expression after plus/minus operator");
					rhs = new ArithmeticExpression(rhs, op2, rhs2);
				}

				return rhs;
			} else {
				return lhs;
			}
		}

		function ternaryExp():Expression {
			var lhs = termExp();

			if (match([TokenType.QuestionMark])) {
				advance();
				var trueExpr = expression();
				if (trueExpr == null)
					throw new Exception("Expected true expression");
				consume(TokenType.Colon, "Expected : after true expression");
				var falseExpr = expression();
				if (falseExpr == null)
					throw new Exception("Expected false expression");
				return new TernaryExpression(lhs, trueExpr, falseExpr);
			} else {
				return lhs;
			}
		}

		function relationalExp():Expression {
			var lhs = ternaryExp();
			if (match([
				TokenType.LessThan,
				TokenType.GreaterThan,
				TokenType.LessThanEqual,
				TokenType.GreaterThanEqual
			])) {
				var op = advance();
				var rhs = ternaryExp();
				if (rhs == null)
					throw new Exception("Expected right hand side");

				rhs = new RelationalExpression(lhs, op, rhs);

				while (match([
					TokenType.LessThan,
					TokenType.GreaterThan,
					TokenType.LessThanEqual,
					TokenType.GreaterThanEqual
				])) {
					var op2 = advance();
					var rhs2 = ternaryExp();
					if (rhs2 == null)
						throw new Exception("Expected right hand side");
					rhs = new RelationalExpression(rhs, op2, rhs2);
				}

				return rhs;
			} else {
				return lhs;
			}
		}

		function bitshiftExp():Expression {
			var lhs = relationalExp();
			if (match([TokenType.LeftBitShift, TokenType.RightBitShift])) {
				var op = advance();
				var rhs = relationalExp();
				if (rhs == null)
					throw new Exception("Expected right hand side");

				rhs = new BitshiftExpression(lhs, op, rhs);

				while (match([TokenType.LeftBitShift, TokenType.RightBitShift])) {
					var op2 = advance();
					var rhs2 = relationalExp();
					if (rhs2 == null)
						throw new Exception("Expected right hand side");
					rhs = new BitshiftExpression(rhs, op2, rhs2);
				}

				return rhs;
			} else
				return lhs;
		}

		function logicalExp():Expression {
			var lhs = bitshiftExp();
			if (match([TokenType.LogicalAnd, TokenType.LogicalOr])) {
				var op = advance();
				var rhs = bitshiftExp();
				if (rhs == null)
					throw new Exception("Expected right hand side");

				rhs = new LogicalExpression(lhs, op, rhs);

				while (match([TokenType.LogicalAnd, TokenType.LogicalOr])) {
					var op2 = advance();
					var rhs2 = bitshiftExp();
					if (rhs2 == null)
						throw new Exception("Expected right hand side");
					rhs = new LogicalExpression(rhs, op2, rhs2);
				}

				return rhs;
			} else
				return lhs;
		}

		function equalityExp():Expression {
			var lhs = logicalExp();

			if (match([
				TokenType.Equal,
				TokenType.NotEqual,
				TokenType.StringEquals,
				TokenType.StringNotEquals
			])) {
				var op = advance();
				var rhs = logicalExp();
				if (rhs == null)
					throw new Exception("Expected right hand side");

				rhs = new EqualityExpression(lhs, op, rhs);

				while (match([
					TokenType.Equal,
					TokenType.NotEqual,
					TokenType.StringEquals,
					TokenType.StringNotEquals
				])) {
					var op2 = advance();
					var rhs2 = logicalExp();
					if (rhs2 == null)
						throw new Exception("Expected right hand side");
					rhs = new EqualityExpression(rhs, op2, rhs2);
				}

				return rhs;
			} else
				return lhs;
		}

		function concatExp():Expression {
			var lhs = equalityExp();

			if (match([
				TokenType.Concat,
				TokenType.TabConcat,
				TokenType.SpaceConcat,
				TokenType.NewlineConcat
			])) {
				var op = advance();
				var rhs = equalityExp();
				if (rhs == null)
					throw new Exception("Expected right hand side");
				rhs = new ConcatenationExpression(lhs, op, rhs);

				while (match([
					TokenType.Concat,
					TokenType.TabConcat,
					TokenType.SpaceConcat,
					TokenType.NewlineConcat
				])) {
					var op2 = advance();
					var rhs2 = equalityExp();
					if (rhs2 == null)
						throw new Exception("Expected right hand side");
					rhs = new ConcatenationExpression(rhs, op2, rhs2);
				}

				return rhs;
			} else
				return lhs;
		}

		return concatExp();
	}

	function label():Label {
		if (match([TokenType.Label])) {
			var label = consume(TokenType.Label, "Expected label");
			var labelexpr = new Label(cast label.literal);
			return labelexpr;
		} else {
			return null;
		}
	}

	function localVariable():LocalVariable {
		if (match([TokenType.Modulus])) {
			advance();
			if (match([
				TokenType.Label, TokenType.Package, TokenType.Return, TokenType.Break, TokenType.Continue, TokenType.While, TokenType.False, TokenType.True,
				TokenType.Function, TokenType.Else, TokenType.If, TokenType.Datablock, TokenType.Case, TokenType.SpaceConcat, TokenType.TabConcat,
				TokenType.NewlineConcat, TokenType.Default, TokenType.New
			])) {
				var n1 = advance();
				var namespace = "";
				while (match([TokenType.DoubleColon])) {
					namespace += cast n1.literal + "::";
					advance();
					if (match([
						TokenType.Label, TokenType.Package, TokenType.Return, TokenType.Break, TokenType.Continue, TokenType.While, TokenType.False,
						TokenType.True, TokenType.Function, TokenType.Else, TokenType.If, TokenType.Datablock, TokenType.Case, TokenType.SpaceConcat,
						TokenType.TabConcat, TokenType.NewlineConcat, TokenType.Default, TokenType.New
					])) {
						n1 = advance();
					} else if (match([TokenType.Int])) {
						n1 = advance();
						if (match([
							TokenType.Label, TokenType.Package, TokenType.Return, TokenType.Break, TokenType.Continue, TokenType.While, TokenType.False,
							TokenType.True, TokenType.Function, TokenType.Else, TokenType.If, TokenType.Datablock, TokenType.Case, TokenType.SpaceConcat,
							TokenType.TabConcat, TokenType.NewlineConcat
						])) {
							var n2 = advance();
							n1 = new Token(TokenType.Label, cast(n1.literal, String) + cast(n2.literal, String),
								cast(n1.literal, String) + cast(n2.literal, String), n1.line);
						}
					} else
						throw new Exception("Expected variable name");
				}

				var localvar = new LocalVariable(new Label(cast n1.literal), namespace == "" ? null : new Label(namespace));
				return localvar;
			} else
				throw new Exception("Expected variable name");
		} else {
			return null;
		}
	}

	function globalVariable():GlobalVariable {
		if (match([TokenType.Dollar])) {
			advance();
			if (match([
				TokenType.Label, TokenType.Package, TokenType.Return, TokenType.Break, TokenType.Continue, TokenType.While, TokenType.False, TokenType.True,
				TokenType.Function, TokenType.Else, TokenType.If, TokenType.Datablock, TokenType.Case, TokenType.SpaceConcat, TokenType.TabConcat,
				TokenType.NewlineConcat
			])) {
				var n1 = advance();
				var namespace = "";
				while (match([TokenType.DoubleColon])) {
					namespace += cast n1.literal + "::";
					advance();
					if (match([
						TokenType.Label, TokenType.Package, TokenType.Return, TokenType.Break, TokenType.Continue, TokenType.While, TokenType.False,
						TokenType.True, TokenType.Function, TokenType.Else, TokenType.If, TokenType.Datablock, TokenType.Case, TokenType.SpaceConcat,
						TokenType.TabConcat, TokenType.NewlineConcat
					])) {
						n1 = advance();
					} else if (match([TokenType.Int])) {
						n1 = advance();
						if (match([
							TokenType.Label, TokenType.Package, TokenType.Return, TokenType.Break, TokenType.Continue, TokenType.While, TokenType.False,
							TokenType.True, TokenType.Function, TokenType.Else, TokenType.If, TokenType.Datablock, TokenType.Case, TokenType.SpaceConcat,
							TokenType.TabConcat, TokenType.NewlineConcat
						])) {
							var n2 = advance();
							n1 = new Token(TokenType.Label, cast(n1.literal, String) + cast(n2.literal, String),
								cast(n1.literal, String) + cast(n2.literal, String), n1.line);
						}
					} else
						throw new Exception("Expected variable name");
				}

				var localvar = new GlobalVariable(new Label(cast n1.literal), namespace == "" ? null : new Label(namespace));
				return localvar;
			} else
				throw new Exception("Expected variable name");
		} else {
			return null;
		}
	}

	function localArray():LocalArray {
		var curpos = current;

		var localvar = localVariable();
		if (localvar == null)
			return null;

		if (!match([TokenType.LeftSquareBracket])) {
			current = curpos;
			return null;
		}

		consume(TokenType.LeftSquareBracket, "Expected [");

		var exprs:Array<Expr> = [];
		var expr = primaryExpressionOrExpression();
		while (expr != null) {
			exprs.push(expr);
			if (match([TokenType.Comma])) {
				advance();
				expr = primaryExpressionOrExpression();
			} else {
				break;
			}
		}
		consume(TokenType.RightSquareBracket, "Expected ]");

		var localArr = new LocalArray(localvar, exprs);
		return localArr;
	}

	function globalArray():GlobalArray {
		var curpos = current;

		var globalvar = globalVariable();
		if (globalvar == null)
			return null;

		if (!match([TokenType.LeftSquareBracket])) {
			current = curpos;
			return null;
		}

		consume(TokenType.LeftSquareBracket, "Expected [");

		var exprs:Array<Expr> = [];
		var expr = primaryExpressionOrExpression();
		while (expr != null) {
			exprs.push(expr);
			if (match([TokenType.Comma])) {
				advance();
				expr = primaryExpressionOrExpression();
			} else {
				break;
			}
		}
		consume(TokenType.RightSquareBracket, "Expected ]");

		var globalArr = new GlobalArray(globalvar, exprs);
		return globalArr;
	}

	function rvalue():Expr {
		if (match([TokenType.Int, TokenType.Float])) {
			return new NumberValue(advance());
		}
		if (match([TokenType.String, TokenType.TaggedString])) {
			return new StringValue(advance());
		}
		if (match([TokenType.Label])) {
			return new LabelValue(advance());
		}
		if (match([TokenType.True, TokenType.False])) {
			return new BooleanValue(advance());
		}
		var objDeclr = objectDeclaration();
		return objDeclr;
	}

	function consume(tokenType:TokenType, message:String) {
		if (check(tokenType)) {
			advance();
			return previous();
		}
		throw new Exception(message);
	}

	function match(types:Array<TokenType>) {
		for (type in types) {
			if (check(type)) {
				return true;
			}
		}
		return false;
	}

	function check(type:TokenType) {
		if (isAtEnd())
			return false;
		return peek().type == type;
	}

	function enterScope() {
		positionStack.add(current);
	}

	function exitScope() {
		current = positionStack.pop();
	}
}
