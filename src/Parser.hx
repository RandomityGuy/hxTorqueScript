package;

import haxe.macro.ExprTools;
import haxe.display.Display.Package;
import haxe.ds.GenericStack;
import expr.Expr;
import haxe.Exception;

@:expose
class Parser {
	var tokens:Array<Token>;

	var comments:Array<Token>;

	var current = 0;

	var panicMode = false;

	var positionStack:GenericStack<Int>;

	var syntaxErrors:Array<SyntaxError> = [];

	public function new(tokens:Array<Token>) {
		this.tokens = [];
		this.comments = [];
		this.positionStack = new GenericStack();
		for (token in tokens) {
			switch (token.type) {
				case Comment(multiline):
					this.comments.push(token);
				default:
					this.tokens.push(token);
			};
		}
	}

	public function parse() {
		return start();
	}

	function start():Array<Stmt> {
		var decls = [];
		var d = decl();
		while (d[0] != null) {
			decls = decls.concat(d);
			d = decl();
		}
		for (err in syntaxErrors) {
			Log.println(err.toString());
		}
		if (syntaxErrors.length != 0) {
			throw new Exception("Syntax errors while parsing");
		}
		return decls;
	}

	function decl():Array<Stmt> {
		try {
			var pkfuncs = packageDecl();
			var d:Stmt = null;
			if (pkfuncs == null) {
				d = functionDecl();
				if (d == null)
					d = stmt();
			}

			return pkfuncs != null ? pkfuncs.map(x -> cast x) : [d];
		} catch (err:SyntaxError) {
			if (!panicMode) {
				syntaxErrors.push(err);
				panicMode = true;
			}
			while (!match([TokenType.Semicolon, TokenType.Eof]) && !this.isAtEnd())
				advance();
			advance();
			panicMode = false;
			return decl();
		}
	}

	function packageDecl():Array<FunctionDeclStmt> {
		if (match([TokenType.Package])) {
			advance(); // Consume the package

			var name = consume(TokenType.Label, "Expected package name");
			consume(TokenType.LBracket, "Expected '{' before package name");

			var decls = [];
			var d = functionDecl();
			d.packageName = name;
			if (d == null)
				throw new SyntaxError("Expected function declaration", tokens[current - 1]);
			while (d != null) {
				decls.push(d);
				d = functionDecl();
				if (d != null)
					d.packageName = name;
			}

			consumeSynchronize(TokenType.RBracket, "Expected '}' after package functions");
			consume(TokenType.Semicolon, "Expected ';' after package block");

			return decls;
		} else {
			return null;
		}
	}

	function functionDecl():FunctionDeclStmt {
		if (match([TokenType.Function])) {
			advance();
			var fnname = consume(TokenType.Label, "Expected function name");
			var parentname:Token = null;
			var parameters = [];

			if (match([TokenType.DoubleColon])) {
				advance(); // Consume the ::
				var temp = consume(TokenType.Label, "Expected function name");
				parentname = fnname;
				fnname = temp;
			}

			consume(TokenType.LParen, "Expected '(' after function name");
			var vardecl = variable();
			while (vardecl != null) {
				parameters.push(vardecl);
				if (match([TokenType.Comma])) {
					advance(); // Consume the comma
					vardecl = variable();
					if (vardecl == null)
						throw new SyntaxError("Expected variable declaration", this.tokens[current - 1]);
				} else {
					vardecl = null;
				}
			}

			consumeSynchronize(TokenType.RParen, "Expected ')' after function parameters");

			consume(TokenType.LBracket, "Expected '{' before function body");

			var body = statementList();

			consumeSynchronize(TokenType.RBracket, "Expected '}' after function body");

			return new FunctionDeclStmt(fnname, parameters, body, parentname);
		} else {
			return null;
		}
	}

	function statementList():Array<Stmt> {
		var stmts = [];
		try {
			var s = stmt();
			while (s != null) {
				stmts.push(s);
				s = stmt();
			}
		} catch (err:SyntaxError) {
			if (!panicMode) {
				syntaxErrors.push(err);
				panicMode = true;
			}
			while (!match([TokenType.Semicolon, TokenType.Eof]) && !this.isAtEnd())
				advance();
			advance();
			panicMode = false;
			return stmts.concat(statementList());
		}
		return stmts;
	}

	function variable():VarExpr {
		var varName = "";
		var varType:VarType;

		var varStart = [
			TokenType.Label, TokenType.Package, TokenType.Return, TokenType.Break, TokenType.Continue, TokenType.While, TokenType.False, TokenType.True,
			TokenType.Function, TokenType.Else, TokenType.If, TokenType.Datablock, TokenType.Case, TokenType.SpaceConcat, TokenType.TabConcat,
			TokenType.NewlineConcat, TokenType.Default, TokenType.New
		];

		var varMid = [TokenType.DoubleColon];

		var varEnd = [
			TokenType.Label,  TokenType.Package, TokenType.Default, TokenType.Return, TokenType.Break, TokenType.Continue,     TokenType.While, TokenType.False,
			 TokenType.True, TokenType.Function,    TokenType.Else,     TokenType.If,   TokenType.New,      TokenType.Int, TokenType.Datablock,  TokenType.Case
		];

		if (match([TokenType.Dollar, TokenType.Modulus])) {
			var typetok = advance(); // Consume the dollar or modulus
			varType = switch (typetok.type) {
				case TokenType.Dollar:
					VarType.Global;
				case TokenType.Modulus:
					VarType.Local;
				default:
					throw new SyntaxError("Unexpected token " + typetok.type, typetok);
			};

			if (match(varStart)) {
				varName = advance().literal;

				while (match(varMid)) {
					var tok = advance();
					varName += switch (tok.type) {
						case DoubleColon:
							"::";
						default:
							tok.literal;
					}

					while (match(varEnd)) {
						varName += advance().literal;
					}
				}

				var retexpr = new VarExpr(new Token(TokenType.Label, varName, varName, typetok.line, typetok.position), null, varType);
				return retexpr;
			} else {
				throw new SyntaxError("Expected variable name", tokens[current - 1]);
			}
			return null;
		} else {
			return null;
		}
	}

	function stmt():Stmt {
		var e:Stmt = breakStmt();
		if (e == null)
			e = returnStmt();
		if (e == null)
			e = continueStmt();
		if (e == null)
			e = expressionStmt();
		if (e == null)
			e = switchStmt();
		if (e == null)
			e = datablockStmt();
		if (e == null)
			e = forStmt();
		if (e == null)
			e = whileStmt();
		if (e == null)
			e = ifStmt();
		return e;
	}

	function returnStmt():ReturnStmt {
		if (match([TokenType.Return])) {
			var line = peek().line;
			advance(); // Consume the return
			if (match([TokenType.Semicolon])) {
				advance(); // Consume the semicolon
				return new ReturnStmt(line, null);
			} else {
				var expr = expression();
				consume(TokenType.Semicolon, "Expected ';' after return expression");
				return new ReturnStmt(line, expr);
			}
		} else {
			return null;
		}
	}

	function continueStmt():ContinueStmt {
		if (match([TokenType.Continue])) {
			var line = peek().line;
			advance(); // Consume the continue
			consume(TokenType.Semicolon, "Expected ';' after continue");
			return new ContinueStmt(line);
		} else {
			return null;
		}
	}

	function breakStmt():BreakStmt {
		if (match([TokenType.Break])) {
			var line = peek().line;
			advance(); // Consume the break
			consume(TokenType.Semicolon, "Expected ';' after break");
			return new BreakStmt(line);
		} else {
			return null;
		}
	}

	function switchStmt():IfStmt {
		if (match([TokenType.Switch])) {
			var switchLine = peek().line;
			advance();
			var isStringSwitch = false;
			if (match([TokenType.Dollar])) {
				advance();
				isStringSwitch = true;
			}

			consume(TokenType.LParen, "Expected '(' after switch");
			var expr = expression();
			consumeSynchronize(TokenType.RParen, "Expected ')' after switch expression");

			consume(TokenType.LBracket, "Expected '{' before switch body");

			var cases = caseBlock();

			if (cases == null)
				throw new SyntaxError("Expected switch cases", tokens[current - 1]);

			consumeSynchronize(TokenType.RBracket, "Expected '}' after switch body");

			// TODO:
			// Change the case OR expr to parse it as (expr || (expr || expr...)) instead of
			// ((expr || expr) || expr)

			function generateCaseCheckExpr(caseData:CaseExpr) {
				var checkExpr:Expr = null;
				if (isStringSwitch) {
					checkExpr = new StrEqExpr(expr, caseData.conditions[0], new Token(TokenType.StringEquals, "$=", "$=", 0, 0));
					caseData.conditions.shift();
					while (caseData.conditions.length > 0) {
						checkExpr = new IntBinaryExpr(checkExpr,
							new StrEqExpr(expr, caseData.conditions.shift(), new Token(TokenType.StringEquals, "$=", "$=", 0, 0)),
							new Token(TokenType.LogicalOr, "||", "||", 0, 0));
					}
					return checkExpr;
				} else {
					checkExpr = new IntBinaryExpr(expr, caseData.conditions[0], new Token(TokenType.Equal, "==", "==", 0, 0));
					caseData.conditions.shift();
					while (caseData.conditions.length > 0) {
						checkExpr = new IntBinaryExpr(checkExpr,
							new IntBinaryExpr(expr, caseData.conditions.shift(), new Token(TokenType.Equal, "==", "==", 0, 0)),
							new Token(TokenType.LogicalOr, "||", "||", 0, 0));
					}
					return checkExpr;
				}
			}

			var ifStmt = new IfStmt(switchLine, generateCaseCheckExpr(cases), cases.stmts, null);

			if (cases.next == null) {
				if (cases.defaultStmts != null)
					if (cases.defaultStmts.length != 0)
						ifStmt.elseBlock = cases.defaultStmts;
			} else {
				var itrIf = ifStmt;
				while (cases.next != null) {
					var cond = generateCaseCheckExpr(cases.next);
					itrIf.elseBlock = [new IfStmt(cond.lineNo, cond, cases.next.stmts, null)];
					itrIf = cast itrIf.elseBlock[0];
					cases = cases.next;

					if (cases.defaultStmts != null) {
						itrIf.elseBlock = cases.defaultStmts;
					}
				}
			}

			return ifStmt;
		} else {
			return null;
		}
	}

	function caseBlock():CaseExpr {
		if (match([TokenType.Case])) {
			advance();
			var caseExprs = [];
			var caseExpr = expression();
			while (caseExpr != null) {
				caseExprs.push(caseExpr);
				if (match([TokenType.Or])) {
					advance();
					caseExpr = expression();
				} else {
					break;
				}
			}
			consume(TokenType.Colon, "Expected ':' after case expression");

			var stmtList = statementList();

			var nextCase = caseBlock();

			if (nextCase == null) {
				var defExprs:Array<Stmt> = null;
				if (match([TokenType.Default])) {
					advance();
					consume(TokenType.Colon, "Expected ':' after default");
					defExprs = statementList();
				}

				return {
					conditions: caseExprs,
					stmts: stmtList,
					defaultStmts: defExprs,
					next: null
				};
			} else {
				return {
					conditions: caseExprs,
					stmts: stmtList,
					defaultStmts: null,
					next: nextCase
				};
			}
		} else {
			return null;
		}
	}

	function datablockStmt():ObjectDeclExpr {
		if (match([TokenType.Datablock])) {
			advance(); // Consume the datablock
			var className = consume(TokenType.Label, "Expected identifier after datablock");

			consume(TokenType.LParen, "Expected '(' after datablock name");
			var name = consume(TokenType.Label, "Expected identifier after datablock name");
			var parentName:Token = null;
			if (match([TokenType.Colon])) {
				advance();
				parentName = consume(TokenType.Label, "Expected identifier after datablock name");
			}
			consumeSynchronize(TokenType.RParen, "Expected ')' after datablock name");

			consume(TokenType.LBracket, "Expected '{' before datablock body");

			var slots = [];
			var slot = slotAssign();
			if (slot == null)
				throw new SyntaxError("Expected slot assignment", tokens[current - 1]);

			while (slot != null) {
				slots.push(slot);
				slot = slotAssign();
			}

			consumeSynchronize(TokenType.RBracket, "Expected '}' after datablock body");
			consume(TokenType.Semicolon, "Expected ';' after datablock body");

			var dbdecl = new ObjectDeclExpr(new ConstantExpr(className), parentName, new ConstantExpr(name), [], slots, [], true);
			dbdecl.structDecl = true;
			return dbdecl;
		} else {
			return null;
		}
	}

	function slotAssign():SlotAssignExpr {
		if (match([TokenType.Label])) {
			var slotName = consume(TokenType.Label, "Expected identifier after slot assignment");

			var arrayIdx:Expr = null;
			if (match([TokenType.LeftSquareBracket])) {
				advance();
				arrayIdx = null;
				var arrayExpr = expression();
				if (arrayExpr == null) {
					throw new SyntaxError("Expected expression after '['", tokens[current - 1]);
				}
				while (arrayExpr != null) {
					if (arrayIdx == null)
						arrayIdx = arrayExpr;
					else
						arrayIdx = new CommaCatExpr(arrayIdx, arrayExpr);
					if (match([TokenType.Comma])) {
						advance();
						arrayExpr = expression();
					} else {
						break;
					}
				}
				consume(TokenType.RightSquareBracket, "Expected ']' after array index");
			}

			consume(TokenType.Assign, "Expected '=' after slot assignment");
			var slotExpr = expression();
			if (slotExpr == null) {
				throw new SyntaxError("Expected expression after '='", tokens[current - 1]);
			}
			consume(TokenType.Semicolon, "Expected ';' after slot assignment");
			return new SlotAssignExpr(null, arrayIdx, slotName, slotExpr);
		} else if (match([TokenType.Datablock])) {
			var slotName = advance();

			consume(TokenType.Assign, "Expected '=' after slot assignment");

			var slotExpr = expression();
			if (slotExpr == null) {
				throw new SyntaxError("Expected expression after '='", tokens[current - 1]);
			}
			consume(TokenType.Semicolon, "Expected ';' after slot assignment");
			return new SlotAssignExpr(null, null, slotName, slotExpr);
		} else {
			return null;
		}
	}

	function forStmt():LoopStmt {
		if (match([TokenType.For])) {
			var forLine = peek().line;
			advance();
			consume(TokenType.LParen, "Expected '(' after 'for'");
			var initExpr = expression();
			consume(TokenType.Semicolon, "Expected ';' after initializer in for loop");
			var condExpr = expression();
			consume(TokenType.Semicolon, "Expected ';' after condition in for loop");
			var iterExpr = expression();
			consumeSynchronize(TokenType.RParen, "Expected ')' after iteration in for loop");

			var body = [];
			if (match([TokenType.LBracket])) {
				advance();
				body = statementList();
				consumeSynchronize(TokenType.RBracket, "Expected '}' after for loop body");
			} else
				body = [stmt()];

			return new LoopStmt(forLine, condExpr, initExpr, iterExpr, body);
		} else {
			return null;
		}
	}

	function whileStmt():LoopStmt {
		if (match([TokenType.While])) {
			var whileLine = peek().line;
			advance();
			consume(TokenType.LParen, "Expected '(' after 'while'");
			var condExpr = expression();
			consumeSynchronize(TokenType.RParen, "Expected ')' after condition in while loop");

			var body = [];
			if (match([TokenType.LBracket])) {
				advance();
				body = statementList();
				consumeSynchronize(TokenType.RBracket, "Expected '}' after for loop body");
			} else
				body = [stmt()];

			return new LoopStmt(whileLine, condExpr, null, null, body);
		} else {
			return null;
		}
	}

	function ifStmt():IfStmt {
		if (match([TokenType.If])) {
			var ifLine = peek().line;
			advance();
			consume(TokenType.LParen, "Expected '(' after 'if'");
			var condExpr = expression();
			consumeSynchronize(TokenType.RParen, "Expected ')' after condition in if statement");

			var body = [];
			if (match([TokenType.LBracket])) {
				advance();
				body = statementList();
				consumeSynchronize(TokenType.RBracket, "Expected '}' after if statement body");
			} else
				body = [stmt()];

			var elseBody:Array<Stmt> = null;
			if (match([TokenType.Else])) {
				advance();
				if (match([TokenType.LBracket])) {
					advance();
					elseBody = statementList();
					if (elseBody.length == 0)
						elseBody = null;
					consumeSynchronize(TokenType.RBracket, "Expected '}' after else statement body");
				} else
					elseBody = [stmt()];
			}

			return new IfStmt(ifLine, condExpr, body, elseBody);
		} else {
			return null;
		}
	}

	function expressionStmt():Stmt {
		var exprstmt = stmtExpr();
		if (exprstmt != null)
			consume(TokenType.Semicolon, "Expected ';' after expression statement");
		return exprstmt;
	}

	function stmtExpr():Expr {
		var curPos = current;

		var expr = expression();
		if (expr != null) {
			if (match([TokenType.Dot])) {
				advance();
				var labelAccess = consume(TokenType.Label, "Expected label after expression");
				var arrAccess:Expr = null;
				if (match([TokenType.LeftSquareBracket])) {
					advance();
					arrAccess = null;
					var arrExpr = expression();
					if (arrExpr == null) {
						throw new SyntaxError("Expected expression after '['", tokens[current - 1]);
					}
					while (arrExpr != null) {
						if (arrAccess == null)
							arrAccess = arrExpr;
						else
							arrAccess = new CommaCatExpr(arrAccess, arrExpr);
						if (match([TokenType.Comma])) {
							advance();
							arrExpr = expression();
						} else {
							break;
						}
					}

					consume(TokenType.RightSquareBracket, "Expected ']' after array index");
				}

				var nextTok = advance();

				switch (nextTok.type) {
					case TokenType.Assign:
						var rexpr = expression();
						return new SlotAssignExpr(expr, arrAccess, labelAccess, rexpr);

					case TokenType.ShiftRightAssign | TokenType.OrAssign | TokenType.XorAssign | TokenType.AndAssign | TokenType.ModulusAssign | TokenType.DivideAssign | TokenType.MultiplyAssign | TokenType.MinusAssign | TokenType.PlusAssign:
						var rexpr = expression();
						return new SlotAssignOpExpr(expr, arrAccess, labelAccess, rexpr, nextTok);

					case TokenType.PlusPlus | TokenType.MinusMinus:
						return new ParenthesisExpr(new SlotAssignOpExpr(expr, arrAccess, labelAccess, null, nextTok));

					case LParen:
						if (arrAccess == null) {
							var funcexprs = [expr];
							var funcexpr = expression();
							while (funcexpr != null) {
								funcexprs.push(funcexpr);
								if (match([TokenType.Comma])) {
									advance();
									funcexpr = expression();
								} else {
									break;
								}
							}
							consume(RParen, "Expected ')' after function call arguments");

							return new FuncCallExpr(labelAccess, null, funcexprs, MethodCall);
						} else {
							throw new SyntaxError("Cannot call array methods with a dot notation accessor", tokens[current - 1]);
						}

					default:
						current = curPos;
						return null;
				}
			} else if (Std.isOfType(expr, VarExpr)) {
				var varExpr:VarExpr = cast expr;
				var arrAccess:Array<Expr> = null;
				if (match([TokenType.LeftSquareBracket])) {
					advance();
					arrAccess = [];
					var arrExpr = expression();
					if (arrExpr == null) {
						throw new SyntaxError("Expected expression after '['", tokens[current - 1]);
					}
					while (arrExpr != null) {
						arrAccess.push(arrExpr);
						if (match([TokenType.Comma])) {
							advance();
							arrExpr = expression();
						} else {
							break;
						}
					}

					consume(TokenType.RightSquareBracket, "Expected ']' after array index");
				}

				var nextTok = advance();

				switch (nextTok.type) {
					case TokenType.ShiftRightAssign | TokenType.OrAssign | TokenType.XorAssign | TokenType.AndAssign | TokenType.ModulusAssign | TokenType.DivideAssign | TokenType.MultiplyAssign | TokenType.MinusAssign | TokenType.PlusAssign:
						var rexpr = expression();
						return new AssignOpExpr(varExpr, rexpr, nextTok);

					case TokenType.PlusPlus | TokenType.MinusMinus:
						return new ParenthesisExpr(new AssignOpExpr(varExpr, null, nextTok));

					case TokenType.Assign:
						var rexpr = expression();
						return new AssignExpr(varExpr, rexpr);

					default:
						current = curPos;
						return null;
				}
			} else {
				return expr;
			}
		} else {
			var varExpr = variable();
			if (varExpr != null) {
				var arrAccess:Array<Expr> = null;
				if (match([TokenType.LeftSquareBracket])) {
					advance();
					arrAccess = [];
					var arrExpr = expression();
					if (arrExpr == null) {
						throw new SyntaxError("Expected expression after '['", tokens[current - 1]);
					}
					while (arrExpr != null) {
						arrAccess.push(arrExpr);
						if (match([TokenType.Comma])) {
							advance();
							arrExpr = expression();
						} else {
							break;
						}
					}

					consume(TokenType.RightSquareBracket, "Expected ']' after array index");
				}

				var nextTok = advance();

				switch (nextTok.type) {
					case TokenType.ShiftRightAssign | TokenType.OrAssign | TokenType.XorAssign | TokenType.AndAssign | TokenType.ModulusAssign | TokenType.DivideAssign | TokenType.MultiplyAssign | TokenType.MinusAssign | TokenType.PlusAssign:
						var rexpr = expression();
						return new AssignOpExpr(varExpr, rexpr, nextTok);

					case TokenType.PlusPlus | TokenType.MinusMinus:
						return new ParenthesisExpr(new AssignOpExpr(varExpr, null, nextTok));

					case TokenType.Assign:
						var rexpr = expression();
						return new AssignExpr(varExpr, rexpr);

					default:
						current = curPos;
						return null;
				}
			} else {
				var objD = objectDecl();
				if (objD != null)
					return objD;
				else {
					if (match([TokenType.Label])) {
						var funcname = consume(TokenType.Label, "Expected any expression statement");
						var parentname = null;
						if (match([TokenType.DoubleColon])) {
							var temp = consume(TokenType.Label, "Expected function name");
							parentname = funcname;
							funcname = temp;
						}

						consume(TokenType.LParen, "Expected parenthesis after function name");
						var funcexprs = [];
						var funcexpr = expression();
						while (funcexpr != null) {
							funcexprs.push(funcexpr);
							if (match([TokenType.Comma])) {
								advance();
								funcexpr = expression();
							} else {
								break;
							}
						}
						consume(TokenType.RParen, "Expected ')' after function parameters");
						return new FuncCallExpr(funcname, parentname, funcexprs,
							cast(parentname.literal, String).toLowerCase() == "parent" ? ParentCall : FunctionCall);
					} else {
						return null;
					}
				}
			}
		}
	}

	function objectDecl():ObjectDeclExpr {
		if (match([TokenType.New])) {
			advance();
			var classNameExpr:Expr = null;
			if (match([TokenType.LParen])) {
				advance();
				classNameExpr = expression();
				consumeSynchronize(TokenType.RParen, "Expected ')' after class name");
			} else
				classNameExpr = new ConstantExpr(consume(TokenType.Label, "Expected class name"));

			consume(TokenType.LParen, "Expected '(' after class name");

			var objNameExpr:Expr = null;
			var parentObj:Token = null;
			var objArgs:Array<Expr> = [];
			if (!match([TokenType.RParen])) {
				objNameExpr = expression();
				if (match([TokenType.Colon])) {
					advance();
					parentObj = consume(TokenType.Label, "Expected parent object name");
				}

				if (match([TokenType.Comma])) {
					objArgs = [];
					var objArg = expression();
					while (objArg != null) {
						objArgs.push(objArg);
						if (match([TokenType.Comma])) {
							advance();
							objArg = expression();
						} else {
							break;
						}
					}
				}

				consumeSynchronize(TokenType.RParen, "Expected ')' after object parameters");
			} else {
				advance(); // Consume the ')'
			}

			if (match([TokenType.LBracket])) {
				advance();

				var slotAssigns = [];
				var sa = slotAssign();
				while (sa != null) {
					slotAssigns.push(sa);
					sa = slotAssign();
				}

				var subObjects = [];
				var so = objectDecl();
				if (so != null)
					consume(TokenType.Semicolon, "Expected ';' after object declaration");
				while (so != null) {
					subObjects.push(so);
					so = objectDecl();
					if (so != null)
						consume(TokenType.Semicolon, "Expected ';' after object declaration");
				}

				consumeSynchronize(TokenType.RBracket, "Expected '}'");

				return new ObjectDeclExpr(classNameExpr, parentObj, objNameExpr, objArgs, slotAssigns, subObjects, false);
			} else {
				return new ObjectDeclExpr(classNameExpr, parentObj, objNameExpr, objArgs, [], [], false);
			}
			return null;
		} else {
			return null;
		}
	}

	function expression():Expr {
		// The whole structure is supposed to be like this in torque, except for when it isnt at times cause fuck strcat ops
		// ternary > logical > xor > modulus > bitwise > eq > strEq > relational > shift > term > factor > primary

		// Special observations for strcat ops
		// strcat < ternary
		// strcat < xor
		// strcat > modulus
		// strcat < bitwise

		// Edge cases:
		// "1" @ "2" $= "1" @ "2" => (("1" @ "2") $= "1") @ "2"
		// 32 + 2 == "3" @ "4" => (32 + 2) == ("3" @ "4")
		// "1" @ "2" ^ "1" @ "2" => ("1" @ "2") ^ ("1" @ "2")

		var chainExpr:Void->Expr = null;

		var ternaryExp:Void->Expr = null;

		function primaryExpr():Expr {
			if (match([TokenType.LParen])) {
				advance();
				var subexpr = expression();
				consume(TokenType.RParen, "Expected ')' after expression");
				return new ParenthesisExpr(subexpr);
			} else if (match([TokenType.Minus])) {
				var tok = advance();
				var subexpr = chainExpr();

				if (Std.isOfType(subexpr, IntBinaryExpr) || Std.isOfType(subexpr, FloatBinaryExpr)) {
					var bexpr = cast(subexpr, BinaryExpr);
					bexpr.left = new FloatUnaryExpr(bexpr.left, tok);
					return bexpr;
				} else
					return new FloatUnaryExpr(subexpr, tok);
			} else if (match([TokenType.Not, TokenType.Tilde])) {
				var tok = advance();
				var subexpr = chainExpr();
				if (Std.isOfType(subexpr, IntBinaryExpr) || Std.isOfType(subexpr, FloatBinaryExpr)) {
					var bexpr = cast(subexpr, BinaryExpr);
					bexpr.left = new IntUnaryExpr(bexpr.left, tok);
					return bexpr;
				} else
					return new IntUnaryExpr(subexpr, tok);
			} else if (match([TokenType.Modulus, TokenType.Dollar])) {
				var varExpr = variable();
				var varIdx:Expr = null;
				if (match([TokenType.LeftSquareBracket])) {
					advance();
					var arrExpr = expression();
					if (arrExpr == null)
						throw new SyntaxError("Expected array index", tokens[current - 1]);

					while (arrExpr != null) {
						if (varIdx == null)
							varIdx = arrExpr;
						else
							varIdx = new CommaCatExpr(varIdx, arrExpr);
						if (match([TokenType.Comma])) {
							advance();
							arrExpr = expression();
						} else {
							break;
						}
					}

					consume(TokenType.RightSquareBracket, "Expected ']' after array index");
				}

				varExpr.arrayIndex = varIdx;
				return varExpr;
			} else if (match([TokenType.String])) {
				var str = advance();
				return new StringConstExpr(str.line, str.literal, false);
			} else if (match([TokenType.TaggedString])) {
				var str = advance();
				return new StringConstExpr(str.line, str.literal, true);
			} else if (match([TokenType.Label, TokenType.Break])) {
				var label = advance();
				return new ConstantExpr(label);
			} else if (match([TokenType.Int])) {
				var intTok = advance();
				return new IntExpr(intTok.line, Std.parseInt(intTok.literal));
			} else if (match([TokenType.Float])) {
				var floatTok = advance();
				return new FloatExpr(floatTok.line, Std.parseFloat(floatTok.literal));
			} else if (match([TokenType.True])) {
				var trueLine = peek().line;
				advance();
				return new IntExpr(trueLine, 1);
			} else if (match([TokenType.False])) {
				var falseLine = peek().line;
				advance();
				return new IntExpr(falseLine, 0);
			} else
				return null;
		}

		chainExpr = () -> {
			var expr = primaryExpr();

			var chExpr:Expr = null;

			if (expr != null) {
				if (match([TokenType.Dot])) {
					advance();
					var labelAccess = consume(TokenType.Label, "Expected label after expression");
					var arrAccess:Expr = null;
					if (match([TokenType.LeftSquareBracket])) {
						advance();
						arrAccess = null;
						var arrExpr = expression();
						if (arrExpr == null) {
							throw new SyntaxError("Expected expression after '['", tokens[current - 1]);
						}
						while (arrExpr != null) {
							if (arrAccess == null)
								arrAccess = arrExpr;
							else
								arrAccess = new CommaCatExpr(arrAccess, arrExpr);
							if (match([TokenType.Comma])) {
								advance();
								arrExpr = expression();
							} else {
								break;
							}
						}

						consume(TokenType.RightSquareBracket, "Expected ']' after array index");
					}

					var nextTok = peek();
					switch (nextTok.type) {
						case TokenType.Assign:
							advance();
							var rexpr = ternaryExp();
							chExpr = new SlotAssignExpr(expr, arrAccess, labelAccess, rexpr);

						case TokenType.ShiftRightAssign | TokenType.OrAssign | TokenType.XorAssign | TokenType.AndAssign | TokenType.ModulusAssign | TokenType.DivideAssign | TokenType.MultiplyAssign | TokenType.MinusAssign | TokenType.PlusAssign:
							advance();
							var rexpr = ternaryExp();
							chExpr = new SlotAssignOpExpr(expr, arrAccess, labelAccess, rexpr, nextTok);

						case TokenType.PlusPlus | TokenType.MinusMinus:
							advance();
							chExpr = new ParenthesisExpr(new SlotAssignOpExpr(expr, arrAccess, labelAccess, null, nextTok));

						case LParen:
							advance();
							if (arrAccess == null) {
								var funcexprs = [expr];
								var funcexpr = expression();
								while (funcexpr != null) {
									funcexprs.push(funcexpr);
									if (match([TokenType.Comma])) {
										advance();
										funcexpr = expression();
									} else {
										break;
									}
								}
								consume(RParen, "Expected ')' after function call arguments");

								chExpr = new FuncCallExpr(labelAccess, null, funcexprs, MethodCall);
							} else {
								throw new SyntaxError("Cannot call array methods with a dot notation accessor", tokens[current - 1]);
							}

						default:
							chExpr = new SlotAccessExpr(expr, arrAccess, labelAccess);
					}
				} else if (Std.isOfType(expr, VarExpr)) {
					var varExpr:VarExpr = cast expr;

					var nextTok = peek();

					switch (nextTok.type) {
						case TokenType.ShiftRightAssign | TokenType.OrAssign | TokenType.XorAssign | TokenType.AndAssign | TokenType.ModulusAssign | TokenType.DivideAssign | TokenType.MultiplyAssign | TokenType.MinusAssign | TokenType.PlusAssign:
							advance();
							var rexpr = ternaryExp();
							chExpr = new AssignOpExpr(varExpr, rexpr, nextTok);

						case TokenType.PlusPlus | TokenType.MinusMinus:
							advance();
							chExpr = new ParenthesisExpr(new AssignOpExpr(varExpr, null, nextTok));

						case TokenType.Assign:
							advance();
							var rexpr = ternaryExp();
							chExpr = new AssignExpr(varExpr, rexpr);

						default:
							chExpr = varExpr;
					}
				} else if (Std.isOfType(expr, ConstantExpr)) {
					if (match([TokenType.LParen])) {
						advance();

						var fnname = cast(expr, ConstantExpr).name;

						var fnArgs = [];
						var fnArg = expression();
						while (fnArg != null) {
							fnArgs.push(fnArg);
							if (match([TokenType.Comma])) {
								advance();
								fnArg = expression();
							} else {
								break;
							}
						}

						consume(TokenType.RParen, "Expected ')' after constant function arguments");

						chExpr = new FuncCallExpr(fnname, null, fnArgs, FunctionCall);
					} else if (match([TokenType.DoubleColon])) {
						advance();
						var parentname = cast(expr, ConstantExpr).name;
						var fnname = consume(TokenType.Label, "Expected a function name after '::'");

						consume(TokenType.LParen, "Expected '(' after constant function name");
						var fnArgs = [];
						var fnArg = expression();
						while (fnArg != null) {
							fnArgs.push(fnArg);
							if (match([TokenType.Comma])) {
								advance();
								fnArg = expression();
							} else {
								break;
							}
						}

						consume(TokenType.RParen, "Expected ')' after constant function arguments");

						chExpr = new FuncCallExpr(fnname, parentname, fnArgs,
							cast(parentname.literal, String).toLowerCase() == "parent" ? ParentCall : FunctionCall);
					} else
						chExpr = expr;
				} else {
					chExpr = expr;
				}
			} else {
				var objD = objectDecl();
				if (objD != null)
					chExpr = objD;
				else {
					return null;
				}
			}

			while (match([TokenType.Dot])) {
				advance();
				var label = consume(TokenType.Label, "Expected a property name after '.'");
				if (match([TokenType.LParen])) {
					advance();
					var fnArgs = [chExpr];
					var fnArg = expression();
					while (fnArg != null) {
						fnArgs.push(fnArg);
						if (match([TokenType.Comma])) {
							advance();
							fnArg = expression();
						} else {
							break;
						}
					}

					consume(TokenType.RParen, "Expected ')' after function arguments");

					chExpr = new FuncCallExpr(label, null, fnArgs, MethodCall);
				} else {
					var arrAccess:Expr = null;
					if (match([TokenType.LeftSquareBracket])) {
						advance();
						arrAccess = null;
						var arrExpr = expression();
						if (arrExpr == null) {
							throw new SyntaxError("Expected expression after '['", tokens[current - 1]);
						}
						while (arrExpr != null) {
							if (arrAccess == null)
								arrAccess = arrExpr;
							else
								arrAccess = new CommaCatExpr(arrAccess, arrExpr);
							if (match([TokenType.Comma])) {
								advance();
								arrExpr = expression();
							} else {
								break;
							}
						}

						consume(TokenType.RightSquareBracket, "Expected ']' after array index");
					}

					var nextTok = peek();
					switch (nextTok.type) {
						case TokenType.Assign:
							advance();
							var rexpr = ternaryExp();
							chExpr = new SlotAssignExpr(chExpr, arrAccess, label, rexpr);

						case TokenType.ShiftRightAssign | TokenType.OrAssign | TokenType.XorAssign | TokenType.AndAssign | TokenType.ModulusAssign | TokenType.DivideAssign | TokenType.MultiplyAssign | TokenType.MinusAssign | TokenType.PlusAssign:
							advance();
							var rexpr = ternaryExp();
							chExpr = new SlotAssignOpExpr(chExpr, arrAccess, label, rexpr, nextTok);

						case TokenType.PlusPlus | TokenType.MinusMinus:
							advance();
							chExpr = new ParenthesisExpr(new SlotAssignOpExpr(chExpr, arrAccess, label, null, nextTok));

						default:
							chExpr = new SlotAccessExpr(chExpr, arrAccess, label);
					}
				}
			}

			return chExpr;
		}

		function factorExp():Expr {
			var lhs = chainExpr();

			if (match([TokenType.Multiply, TokenType.Divide, TokenType.Modulus])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance(); // Consume the operator
				var rhs = chainExpr();
				if (rhs == null)
					throw new SyntaxError("Expected rhs after bitwise operator", tokens[current - 1]);

				rhs = op.type != TokenType.Modulus ? new FloatBinaryExpr(lhs, rhs, op) : new IntBinaryExpr(lhs, rhs, op);

				while (match([TokenType.Multiply, TokenType.Divide, TokenType.Modulus])) {
					var op2 = advance(); // Consume the operator
					var rhs2 = chainExpr();
					if (rhs2 == null)
						throw new SyntaxError("Expected rhs after bitwise operator", tokens[current - 1]);

					rhs = op.type != TokenType.Modulus ? new FloatBinaryExpr(rhs, rhs2, op2) : new IntBinaryExpr(rhs, rhs2, op2);
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else {
				return lhs;
			}
		}

		function termExp():Expr {
			var lhs = factorExp();

			if (match([TokenType.Plus, TokenType.Minus])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance(); // Consume the plus/minus operator
				var rhs = factorExp();
				if (rhs == null)
					throw new SyntaxError("Expected expression after plus/minus operator", tokens[current - 1]);
				rhs = new FloatBinaryExpr(lhs, rhs, op);

				while (match([TokenType.Plus, TokenType.Minus])) {
					var op2 = advance(); // Consume the plus/minus operator
					var rhs2 = factorExp();
					if (rhs2 == null)
						throw new SyntaxError("Expected expression after plus/minus operator", tokens[current - 1]);
					rhs = new FloatBinaryExpr(rhs, rhs2, op2);
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else {
				return lhs;
			}
		}

		function bitshiftExp():Expr {
			var lhs = termExp();
			if (match([TokenType.LeftBitShift, TokenType.RightBitShift])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance();
				var rhs = termExp();
				if (rhs == null)
					throw new SyntaxError("Expected right hand side", tokens[current - 1]);

				rhs = new IntBinaryExpr(lhs, rhs, op);

				while (match([TokenType.LeftBitShift, TokenType.RightBitShift])) {
					var op2 = advance();
					var rhs2 = termExp();
					if (rhs2 == null)
						throw new SyntaxError("Expected right hand side", tokens[current - 1]);
					rhs = new IntBinaryExpr(rhs, rhs2, op2);
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else
				return lhs;
		}

		function strOpExp():Expr {
			var lhs = bitshiftExp();

			if (match([
				TokenType.Concat,
				TokenType.TabConcat,
				TokenType.SpaceConcat,
				TokenType.NewlineConcat,
				TokenType.StringEquals,
				TokenType.StringNotEquals
			])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance();
				var rhs = bitshiftExp();
				if (rhs == null)
					throw new SyntaxError("Expected right hand side", tokens[current - 1]);
				rhs = switch (op.type) {
					case TokenType.Concat | TokenType.TabConcat | TokenType.SpaceConcat | TokenType.NewlineConcat:
						new StrCatExpr(lhs, rhs, op);
					case TokenType.StringEquals | TokenType.StringNotEquals:
						new StrEqExpr(lhs, rhs, op);

					default:
						null;
				}

				while (match([
					TokenType.Concat,
					TokenType.TabConcat,
					TokenType.SpaceConcat,
					TokenType.NewlineConcat,
					TokenType.StringEquals,
					TokenType.StringNotEquals
				])) {
					var op2 = advance();
					var rhs2 = bitshiftExp();
					if (rhs2 == null)
						throw new SyntaxError("Expected right hand side", tokens[current - 1]);
					rhs = switch (op2.type) {
						case TokenType.Concat | TokenType.TabConcat | TokenType.SpaceConcat | TokenType.NewlineConcat:
							new StrCatExpr(rhs, rhs2, op2);
						case TokenType.StringEquals | TokenType.StringNotEquals:
							new StrEqExpr(rhs, rhs2, op2);

						default:
							null;
					}
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else
				return lhs;
		}

		function relationalExp():Expr {
			var lhs = strOpExp();
			if (match([
				TokenType.LessThan,
				TokenType.GreaterThan,
				TokenType.LessThanEqual,
				TokenType.GreaterThanEqual
			])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance();
				var rhs = strOpExp();
				if (rhs == null)
					throw new SyntaxError("Expected right hand side", tokens[current - 1]);

				rhs = new IntBinaryExpr(lhs, rhs, op);

				while (match([
					TokenType.LessThan,
					TokenType.GreaterThan,
					TokenType.LessThanEqual,
					TokenType.GreaterThanEqual
				])) {
					var op2 = advance();
					var rhs2 = strOpExp();
					if (rhs2 == null)
						throw new SyntaxError("Expected right hand side", tokens[current - 1]);
					rhs = new IntBinaryExpr(rhs, rhs2, op2);
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else {
				return lhs;
			}
		}

		function equalityExp():Expr {
			var lhs = relationalExp();

			if (match([TokenType.Equal, TokenType.NotEqual])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance();
				var rhs = relationalExp();
				if (rhs == null)
					throw new SyntaxError("Expected right hand side", tokens[current - 1]);

				rhs = switch (op.type) {
					case TokenType.Equal | TokenType.NotEqual:
						new IntBinaryExpr(lhs, rhs, op);

					default:
						null;
				}

				while (match([TokenType.Equal, TokenType.NotEqual])) {
					var op2 = advance();
					var rhs2 = relationalExp();
					if (rhs2 == null)
						throw new SyntaxError("Expected right hand side", tokens[current - 1]);
					rhs = switch (op.type) {
						case TokenType.Equal | TokenType.NotEqual:
							new IntBinaryExpr(rhs, rhs2, op2);

						default:
							null;
					}
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else
				return lhs;
		}

		function andExp():Expr {
			var lhs = equalityExp();
			if (match([TokenType.BitwiseAnd])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance(); // Consume the bitwise operator
				var rhs = equalityExp();
				if (rhs == null)
					throw new SyntaxError("Expected expression after bitwise operator", tokens[current - 1]);

				rhs = new IntBinaryExpr(lhs, rhs, op);

				while (match([TokenType.BitwiseAnd])) {
					var op2 = advance(); // Consume the bitwise operator
					var rhs2 = equalityExp();
					if (rhs2 == null)
						throw new SyntaxError("Expected expression after bitwise operator", tokens[current - 1]);

					rhs = new IntBinaryExpr(rhs, rhs2, op2);
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else {
				return lhs;
			}
		}

		function xorExp():Expr {
			var lhs = andExp();
			if (match([TokenType.BitwiseXor])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance(); // Consume the bitwise operator
				var rhs = andExp();
				if (rhs == null)
					throw new SyntaxError("Expected expression after bitwise operator", tokens[current - 1]);

				rhs = new IntBinaryExpr(lhs, rhs, op);

				while (match([TokenType.BitwiseXor])) {
					var op2 = advance(); // Consume the bitwise operator
					var rhs2 = andExp();
					if (rhs2 == null)
						throw new SyntaxError("Expected expression after bitwise operator", tokens[current - 1]);

					rhs = new IntBinaryExpr(rhs, rhs2, op2);
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else {
				return lhs;
			}
		}

		function orExp():Expr {
			var lhs = xorExp();
			if (match([TokenType.BitwiseOr])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance(); // Consume the bitwise operator
				var rhs = xorExp();
				if (rhs == null)
					throw new SyntaxError("Expected expression after bitwise operator", tokens[current - 1]);

				rhs = new IntBinaryExpr(lhs, rhs, op);

				while (match([TokenType.BitwiseOr])) {
					var op2 = advance(); // Consume the bitwise operator
					var rhs2 = xorExp();
					if (rhs2 == null)
						throw new SyntaxError("Expected expression after bitwise operator", tokens[current - 1]);

					rhs = new IntBinaryExpr(rhs, rhs2, op2);
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else {
				return lhs;
			}
		}

		function logicalExp():Expr {
			var lhs = orExp();
			if (match([TokenType.LogicalAnd, TokenType.LogicalOr])) {
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var op = advance();
				var rhs = orExp();
				if (rhs == null)
					throw new SyntaxError("Expected right hand side", tokens[current - 1]);

				rhs = new IntBinaryExpr(lhs, rhs, op);

				while (match([TokenType.LogicalAnd, TokenType.LogicalOr])) {
					var op2 = advance();
					var rhs2 = orExp();
					if (rhs2 == null)
						throw new SyntaxError("Expected right hand side", tokens[current - 1]);
					rhs = new IntBinaryExpr(rhs, rhs2, op2);
				}

				if (lhsAssign) {
					lhsExpr.expr = rhs;
					return lhsExpr;
				} else {
					return rhs;
				}
			} else
				return lhs;
		}

		ternaryExp = () -> {
			var lhs = logicalExp();

			if (match([TokenType.QuestionMark])) {
				advance();
				var lhsExpr:Dynamic = null;

				var lhsAssign = false;
				if (Std.isOfType(lhs, AssignExpr) || Std.isOfType(lhs, AssignOpExpr) || Std.isOfType(lhs, SlotAssignExpr)
					|| Std.isOfType(lhs, SlotAssignOpExpr)) {
					lhsExpr = cast lhs;
					lhs = lhsExpr.expr;
					lhsAssign = true;
				}

				var trueExpr = expression();
				if (trueExpr == null)
					throw new SyntaxError("Expected true expression", tokens[current - 1]);
				consume(TokenType.Colon, "Expected : after true expression");
				var falseExpr = expression();
				if (falseExpr == null)
					throw new SyntaxError("Expected false expression", tokens[current - 1]);

				if (lhsAssign) {
					lhsExpr.expr = new ConditionalExpr(lhs, trueExpr, falseExpr);
					return lhsExpr;
				} else
					return new ConditionalExpr(lhs, trueExpr, falseExpr);
			} else {
				return lhs;
			}
		}

		return ternaryExp();
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

	function consume(tokenType:TokenType, message:String) {
		if (check(tokenType)) {
			advance();
			return previous();
		}
		throw new SyntaxError(message, tokens[current - 1]);
	}

	function consumeSynchronize(tokenType:TokenType, message:String) {
		if (check(tokenType)) {
			advance();
			return previous();
		}
		if (!panicMode) {
			this.syntaxErrors.push(new SyntaxError(message, tokens[current - 1]));
			panicMode = true;
		}
		while (!check(tokenType) && !isAtEnd())
			advance();
		advance();
		panicMode = false; // Synchronized
		return previous();
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
