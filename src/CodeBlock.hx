import expr.Expr.FuncCallType;
import console.SimSet;
import console.SimGroup;
import console.SimDataBlock;
import console.ConsoleObjectConstructors;
import expr.OpCode;
import console.SimObject;
import console.Namespace;
import Compiler.IdentTable;
import haxe.Exception;
import haxe.io.BytesInput;
import console.Namespace.NamespaceEntry;

class CodeBlock {
	var globalFloatTable:Array<Float> = [];
	var functionFloatTable:Array<Float> = [];
	var globalStringTable:String;
	var functionStringTable:String;

	var codeStream:Array<Int> = [];
	var lineBreakPairs:Array<Int> = [];

	var opCodeLookup:Map<Int, String> = [];

	var identMap:Map<Int, String> = [0 => null];
	var identMapSize = 1;

	var resolveFuncId:Int = 0;

	var resolveFuncMap:Map<Int, NamespaceEntry> = new Map<Int, NamespaceEntry>();

	var dsoVersion:Int;

	var vm:VM;

	var fileName:String;

	public var addedFunctions:Bool = false;

	public function new(vm:VM, fileName:String) {
		this.vm = vm;
		this.fileName = fileName;
		opCodeLookup = [
			0 => "FuncDecl", 1 => "CreateObject", 2 => "CreateDataBlock", 3 => "NameObject", 4 => "AddObject", 5 => "EndObject", 6 => "JmpIffNot",
			7 => "JmpIfNot", 8 => "JmpIff", 9 => "JmpIf", 10 => "JmpIfNotNP", 11 => "JmpIfNP", 12 => "Jmp", 13 => "Return", 14 => "CmpEQ", 15 => "CmpGT",
			16 => "CmpGE", 17 => "CmpLT", 18 => "CmpLE", 19 => "CmpNE", 20 => "Xor", 21 => "Mod", 22 => "BitAnd", 23 => "BitOr", 24 => "Not", 25 => "NotF",
			26 => "OnesComplement", 27 => "Shr", 28 => "Shl", 29 => "And", 30 => "Or", 31 => "Add", 32 => "Sub", 33 => "Mul", 34 => "Div", 35 => "Neg",
			36 => "SetCurVar", 37 => "SetCurVarCreate", 38 => "SetCurVarArray", 39 => "SetCurVarArrayCreate", 40 => "LoadVarUInt", 41 => "LoadVarFlt",
			42 => "LoadVarStr", 43 => "SaveVarUInt", 44 => "SaveVarFlt", 45 => "SaveVarStr", 46 => "SetCurObject", 47 => "SetCurObjectNew",
			48 => "SetCurField", 49 => "SetCurFieldArray", 50 => "LoadFieldUInt", 51 => "LoadFieldFlt", 52 => "LoadFieldStr", 53 => "SaveFieldUInt",
			54 => "SaveFieldFlt", 55 => "SaveFieldStr", 56 => "StrToUInt", 57 => "StrToFlt", 58 => "StrToNone", 59 => "FltToUInt", 60 => "FltToStr",
			61 => "FltToNone", 62 => "UIntToFlt", 63 => "UIntToStr", 64 => "UIntToNone", 65 => "LoadImmedUInt", 66 => "LoadImmedFlt", 67 => "TagToStr",
			68 => "LoadImmedStr", 69 => "LoadImmedIdent", 70 => "CallFuncResolve", 71 => "CallFunc", 72 => "ProcessArgs", 73 => "AdvanceStr",
			74 => "AdvanceStrAppendChar", 75 => "AdvanceStrComma", 76 => "AdvanceStrNul", 77 => "RewindStr", 78 => "TerminateRewindStr", 79 => "CompareStr",
			80 => "Push", 81 => "PushFrame", 82 => "Break", 83 => "Invalid"
		];
	}

	public function load(inData:BytesInput) {
		dsoVersion = inData.readInt32();
		if (dsoVersion != 33)
			throw new Exception("Incorrect DSO version: " + dsoVersion);

		var stSize = inData.readInt32();
		globalStringTable = "";
		for (i in 0...stSize) {
			globalStringTable += String.fromCharCode(inData.readByte());
		}
		var size = inData.readInt32();
		for (i in 0...size)
			globalFloatTable.push(inData.readDouble());

		var stSize = inData.readInt32();
		functionStringTable = "";
		for (i in 0...stSize) {
			functionStringTable += String.fromCharCode(inData.readByte());
		}

		size = inData.readInt32();
		for (i in 0...size)
			functionFloatTable.push(inData.readDouble());

		var codeSize = inData.readInt32();
		var lineBreakPairCount = inData.readInt32();
		for (i in 0...codeSize) {
			var curByte = inData.readByte();
			if (curByte == 0xFF) {
				codeStream.push(inData.readInt32());
			} else {
				codeStream.push(curByte);
			}
		}

		for (i in 0...lineBreakPairCount * 2) {
			lineBreakPairs.push(inData.readInt32());
		}

		var identTable = new IdentTable();

		identTable.read(inData);

		for (ident => offsets in identTable.identMap) {
			var identStr = getStringTableValue(globalStringTable, ident);
			var identId = identMapSize;
			for (offset in offsets) {
				codeStream[offset] = identMapSize;
			}
			identMap.set(identId, identStr);
			identMapSize++;
		}
	}

	function getStringTableValue(table:String, offset:Int) {
		return table.substr(offset, table.indexOf("\x00", offset) - offset);
	}

	public function exec(ip:Int, functionName:Null<String>, namespace:Namespace, fnArgs:Array<String>, noCalls:Bool, packageName:String) {
		var currentStringTable:String = null;
		var currentFloatTable:Array<Float> = null;

		vm.STR.clearFunctionOffset();
		var thisFunctionName:String = null;
		var argc = fnArgs.length;
		if (fnArgs.length != 0) {
			var fnArgc = codeStream[ip + 5];
			thisFunctionName = identMap.get(codeStream[ip]);
			argc = cast Math.min(fnArgs.length - 1, fnArgc);

			if (vm.traceOn) {
				Log.print("Entering ");
				if (packageName != null) {
					Log.print('[${packageName}] ');
				}
				if (namespace != null && namespace.name != null) {
					Log.print('${namespace.name}::${thisFunctionName}(');
				} else {
					Log.print('${thisFunctionName}(');
				}
				for (i in 0...argc) {
					Log.print('${fnArgs[i]}');
					if (i != argc - 1) {
						Log.print(', ');
					}
				}
				Log.println(')');
			}

			vm.evalState.pushFrame(thisFunctionName, namespace);
			for (i in 0...argc) {
				var varName = identMap.get(codeStream[ip + 6 + i]);
				vm.evalState.setCurVarNameCreate(varName);
				vm.evalState.setStringVariable(fnArgs[i + 1]);
			}
			ip += 6 + fnArgc;
			currentFloatTable = functionFloatTable;
			currentStringTable = functionStringTable;
		} else {
			currentFloatTable = globalFloatTable;
			currentStringTable = globalStringTable;
		}

		var curField:String = null;
		var curFieldArrayIndex:String = null;
		var currentNewObject:SimObject = null;
		var curObject:SimObject = null;

		var objParent:String = null;

		// now its the interpreter thingy
		var breakContinue = false;
		var breakContinueIns:OpCode = OpCode.Invalid;

		var failJump:Int = 0;

		var callArgs = [];

		var saveObj:SimObject = null;

		while (true) {
			var instruction:OpCode = !breakContinue ? cast codeStream[ip++] : breakContinueIns;

			if (breakContinue)
				breakContinue = false;

			switch (instruction) {
				case OpCode.FuncDecl:
					if (!noCalls) {
						var fnName = identMap.get(codeStream[ip]);
						var fnNamespace = identMap.get(codeStream[ip + 1]);
						var pkg = identMap.get(codeStream[ip + 2]);
						var hasBody = codeStream[ip + 3] == 1;
						var nmspc:Namespace = null;
						for (n in vm.namespaces) {
							if (n.name == fnNamespace && n.pkg == pkg) {
								nmspc = n;
								break;
							}
						}
						if (nmspc == null) {
							nmspc = new Namespace(fnNamespace, pkg, null);
							vm.namespaces.push(nmspc);
						}
						nmspc.addFunction(fnName, hasBody ? ip : 0, this);
						addedFunctions = true;
					}
					ip = codeStream[ip + 4];

				case OpCode.CreateObject:
					if (noCalls) {
						ip = failJump;
					}
					objParent = identMap.get(codeStream[ip]);
					var datablock = codeStream[ip + 1] == 1;
					failJump = codeStream[ip + 2];
					callArgs = vm.STR.getArgs("");

					currentNewObject = null;
					if (datablock) {
						var db:SimObject = vm.dataBlocks.get(callArgs[2]);
						if (db != null) {
							if (db.getClassName().toLowerCase() == callArgs[1].toLowerCase()) {
								Log.println('Cannot re-declare data block ${callArgs[1]} with a different class.');
								ip = failJump;
								continue;
							}
							currentNewObject = db;
						}
					}
					if (currentNewObject == null) {
						if (!datablock) {
							if (!ConsoleObjectConstructors.constructorMap.exists(callArgs[1])) {
								Log.println('Unable to instantantiate non con-object class ${callArgs[1]}');
								ip = failJump;
								continue;
							}
							currentNewObject = cast ConsoleObjectConstructors.constructorMap.get(callArgs[1])();
						} else {
							currentNewObject = new SimDataBlock();
							currentNewObject.className = callArgs[1];
						}
						currentNewObject.assignId(datablock ? vm.nextDatablockId++ : vm.nextSimId++);
						if (objParent != null) {
							var parent = vm.simObjects.get(objParent);
							if (parent != null) {
								currentNewObject.assignFieldsFrom(parent);
							} else {
								Log.println('Parent object ${objParent} for ${callArgs[1]} does not exist.');
							}
						}
						if (callArgs.length > 2) {
							currentNewObject.name = callArgs[2];
						}
						if (callArgs.length > 3) {
							if (!currentNewObject.processArguments(callArgs.slice(3))) {
								currentNewObject = null;
								ip = failJump;
								continue;
							}
						}
					}
					ip += 3;
				case OpCode.CreateDataBlock:
					false; // Do nothing

				case OpCode.NameObject:
					false; // Do nothing

				case OpCode.AddObject:
					var root = codeStream[ip++] == 1;
					var added:Bool = false;
					if (!vm.simObjects.exists(currentNewObject.name)) {
						added = true;
						vm.simObjects.set(currentNewObject.getName(), currentNewObject);
					}
					vm.idMap.set(currentNewObject.id, currentNewObject);
					currentNewObject.register(vm);

					var datablock:SimDataBlock = Std.isOfType(currentNewObject, SimDataBlock) ? cast currentNewObject : null;
					if (datablock != null) {
						if (!datablock.preload()) {
							Log.println('Datablock ${datablock.getName()} failed to preload.');
							ip = failJump;
							vm.idMap.remove(currentNewObject.id);
							if (added)
								vm.simObjects.remove(currentNewObject.getName());
							continue;
						} else {
							vm.dataBlocks.set(currentNewObject.getName(), datablock);
						}
					}
					var groupAddId = vm.intStack.first();
					if (!root || currentNewObject.group == null) {
						if (root) {
							vm.rootGroup.addObject(currentNewObject);
						} else {
							if (vm.idMap.get(groupAddId) != null) {
								if (Std.isOfType(currentNewObject, SimGroup) || Std.isOfType(currentNewObject, SimSet))
									cast(vm.idMap.get(groupAddId), SimSet).addObject(currentNewObject);
								else {
									vm.rootGroup.addObject(currentNewObject);
								}
							} else {
								vm.rootGroup.addObject(currentNewObject);
							}
						}
					}
					if (root) {
						vm.intStack.pop();
					}
					vm.intStack.add(currentNewObject.id);

				case OpCode.EndObject:
					var root = codeStream[ip++] > 0;
					if (!root)
						vm.intStack.pop();

				case OpCode.JmpIffNot:
					if (vm.floatStack.pop() > 0) {
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIfNot:
					if (vm.intStack.pop() > 0) {
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIff:
					if (vm.floatStack.pop() <= 0) {
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIf:
					if (vm.intStack.pop() <= 0) {
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIfNotNP:
					if (vm.intStack.first() > 0) {
						vm.intStack.pop();
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIfNP:
					if (vm.intStack.first() <= 0) {
						vm.intStack.pop();
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.Jmp:
					ip = codeStream[ip];

				case OpCode.Return:
					break;

				case OpCode.CmpEQ:
					vm.intStack.add(vm.floatStack.pop() == vm.floatStack.pop() ? 1 : 0);

				case OpCode.CmpGT:
					vm.intStack.add(vm.floatStack.pop() > vm.floatStack.pop() ? 1 : 0);

				case OpCode.CmpGE:
					vm.intStack.add(vm.floatStack.pop() >= vm.floatStack.pop() ? 1 : 0);

				case OpCode.CmpLT:
					vm.intStack.add(vm.floatStack.pop() < vm.floatStack.pop() ? 1 : 0);

				case OpCode.CmpLE:
					vm.intStack.add(vm.floatStack.pop() <= vm.floatStack.pop() ? 1 : 0);

				case OpCode.CmpNE:
					vm.intStack.add(vm.floatStack.pop() != vm.floatStack.pop() ? 1 : 0);

				case OpCode.Xor:
					vm.intStack.add(vm.intStack.pop() ^ vm.intStack.pop());

				case OpCode.Mod:
					vm.intStack.add(vm.intStack.pop() % vm.intStack.pop());

				case OpCode.BitAnd:
					vm.intStack.add(vm.intStack.pop() & vm.intStack.pop());

				case OpCode.BitOr:
					vm.intStack.add(vm.intStack.pop() | vm.intStack.pop());

				case OpCode.Not:
					vm.intStack.add(vm.intStack.pop() > 0 ? 0 : 1);

				case OpCode.NotF:
					vm.intStack.add(vm.floatStack.pop() > 0 ? 0 : 1);

				case OpCode.OnesComplement:
					vm.intStack.add(~vm.intStack.pop());

				case OpCode.Shl:
					vm.intStack.add(cast vm.intStack.pop() << vm.intStack.pop());

				case OpCode.Shr:
					vm.intStack.add(cast vm.intStack.pop() >> vm.intStack.pop());

				case OpCode.And:
					vm.intStack.add(cast vm.intStack.pop() > 0 && vm.intStack.pop() > 0);

				case OpCode.Or:
					vm.intStack.add(cast vm.intStack.pop() > 0 || vm.intStack.pop() > 0);

				case OpCode.Add:
					vm.floatStack.add(vm.floatStack.pop() + vm.floatStack.pop());

				case OpCode.Sub:
					vm.floatStack.add(vm.floatStack.pop() - vm.floatStack.pop());

				case OpCode.Mul:
					vm.floatStack.add(vm.floatStack.pop() * vm.floatStack.pop());

				case OpCode.Div:
					vm.floatStack.add(vm.floatStack.pop() / vm.floatStack.pop());

				case OpCode.Neg:
					vm.floatStack.add(-vm.floatStack.pop());

				case OpCode.SetCurVar:
					var varName = identMap.get(codeStream[ip++]);
					vm.evalState.setCurVarName(varName);

				case OpCode.SetCurVarCreate:
					var varName = identMap.get(codeStream[ip++]);
					vm.evalState.setCurVarNameCreate(varName);

				case OpCode.SetCurVarArray:
					var varName = vm.STR.getSTValue();
					vm.evalState.setCurVarName(varName);

				case OpCode.SetCurVarArrayCreate:
					var varName = vm.STR.getSTValue();
					vm.evalState.setCurVarNameCreate(varName);

				case OpCode.LoadVarUInt:
					vm.intStack.add(vm.evalState.getIntVariable());

				case OpCode.LoadVarFlt:
					vm.floatStack.add(vm.evalState.getFloatVariable());

				case OpCode.LoadVarStr:
					vm.STR.setStringValue(vm.evalState.getStringVariable());

				case OpCode.SaveVarUInt:
					vm.evalState.setIntVariable(vm.intStack.first());

				case OpCode.SaveVarFlt:
					vm.evalState.setFloatVariable(vm.floatStack.first());

				case OpCode.SaveVarStr:
					vm.evalState.setStringVariable(vm.STR.getSTValue());

				case OpCode.SetCurObject:
					curObject = vm.simObjects.get(vm.STR.getSTValue());
					if (curObject == null)
						curObject = vm.idMap.get(Std.parseInt(vm.STR.getSTValue()));

				case OpCode.SetCurObjectNew:
					curObject = currentNewObject;

				case OpCode.SetCurField:
					curField = identMap.get(codeStream[ip++]);
					curFieldArrayIndex = null;

				case OpCode.SetCurFieldArray:
					curFieldArrayIndex = vm.STR.getSTValue();

				case OpCode.LoadFieldUInt:
					if (curObject != null)
						vm.intStack.add(cast Std.parseFloat(curObject.getDataField(curField, curFieldArrayIndex)));
					else
						vm.intStack.add(0);

				case OpCode.LoadFieldFlt:
					if (curObject != null)
						vm.floatStack.add(Std.parseFloat(curObject.getDataField(curField, curFieldArrayIndex)));
					else
						vm.floatStack.add(0);

				case OpCode.LoadFieldStr:
					if (curObject != null)
						vm.STR.setStringValue(curObject.getDataField(curField, curFieldArrayIndex));
					else
						vm.STR.setStringValue("");

				case OpCode.SaveFieldUInt:
					vm.STR.setIntValue(vm.intStack.first());
					if (curObject != null)
						curObject.setDataField(curField, curFieldArrayIndex, vm.STR.getSTValue());

				case OpCode.SaveFieldFlt:
					vm.STR.setFloatValue(vm.floatStack.first());
					if (curObject != null)
						curObject.setDataField(curField, curFieldArrayIndex, vm.STR.getSTValue());

				case OpCode.SaveFieldStr:
					if (curObject != null)
						curObject.setDataField(curField, curFieldArrayIndex, vm.STR.getSTValue());

				case OpCode.StrToUInt:
					vm.intStack.add(vm.STR.getIntValue());

				case OpCode.StrToFlt:
					vm.floatStack.add(vm.STR.getFloatValue());

				case OpCode.StrToNone:
					false;

				case OpCode.FltToUInt:
					vm.intStack.add(cast vm.floatStack.pop());

				case OpCode.FltToStr:
					vm.STR.setFloatValue(vm.floatStack.pop());

				case OpCode.FltToNone:
					vm.floatStack.pop();

				case OpCode.UIntToFlt:
					vm.floatStack.add(vm.intStack.pop());

				case OpCode.UIntToStr:
					vm.STR.setIntValue(vm.intStack.pop());

				case OpCode.UIntToNone:
					vm.intStack.pop();

				case OpCode.LoadImmedUInt:
					vm.intStack.add(codeStream[ip++]);

				case OpCode.LoadImmedFlt:
					vm.floatStack.add(currentFloatTable[codeStream[ip++]]);

				case OpCode.TagToStr:
					codeStream[ip - 1] = cast OpCode.LoadImmedStr;
					if (getStringTableValue(currentStringTable, codeStream[ip]).charCodeAt(0) != 1) {
						var id = vm.taggedStrings.length;
						vm.taggedStrings.push(getStringTableValue(currentStringTable, codeStream[ip]));
						var idStr = '${id}';
						var before = currentStringTable.substring(0, codeStream[ip]);
						var after = currentStringTable.substring(codeStream[ip] + 8);
						var insert = StringTools.rpad('\x01${idStr}', "\x00", 7);
						currentStringTable = before + insert + after;
					}

				case OpCode.LoadImmedStr:
					vm.STR.setStringValue(getStringTableValue(currentStringTable, codeStream[ip++]));

				case OpCode.LoadImmedIdent:
					vm.STR.setStringValue(identMap.get(codeStream[ip++]));

				case OpCode.CallFuncResolve:
					var fnNamespace = identMap.get(codeStream[ip + 1]);
					var fnName = identMap.get(codeStream[ip]);
					var nsEntry = vm.findFunction(fnNamespace, fnName);
					if (nsEntry == null) {
						ip += 3;
						Log.println('Unable to find function ${fnNamespace}::${fnName}');
						vm.STR.getArgs(fnName);
						continue;
					}
					codeStream[ip - 1] = cast OpCode.CallFunc;
					codeStream[ip + 1] = resolveFuncId;
					resolveFuncMap.set(resolveFuncId, nsEntry);
					resolveFuncId++;
					ip--;
					continue;

				case OpCode.CallFunc:
					var fnName = identMap.get(codeStream[ip]);
					var callType = codeStream[ip + 2];
					ip += 3;
					callArgs = vm.STR.getArgs(fnName);
					var nsEntry:NamespaceEntry = null;
					var ns:Namespace = null;
					if (callType == cast FuncCallType.FunctionCall) {
						nsEntry = this.resolveFuncMap.get(codeStream[ip - 2]);
					} else if (callType == cast FuncCallType.MethodCall) {
						saveObj = vm.evalState.thisObject;
						vm.evalState.thisObject = vm.simObjects.get(callArgs[1]);
						if (vm.evalState.thisObject == null)
							vm.evalState.thisObject = vm.idMap.get(Std.parseInt(callArgs[1]));
						if (vm.evalState.thisObject == null) {
							Log.println('Unable to find object ${callArgs[1]} attempting to call function ${fnName}');
							continue;
						}
						nsEntry = vm.findFunction(vm.evalState.thisObject.getClassName(), fnName);
						ns = nsEntry != null ? nsEntry.namespace : null;
					} else { // Parent Call
						if (namespace != null) {
							ns = namespace.parent;
							if (ns != null) {
								nsEntry = ns.find(fnName);
							} else {
								nsEntry = null;
							}
						} else {
							ns = null;
							nsEntry = null;
						}
					}
					if (nsEntry == null || noCalls) {
						if (!noCalls) {
							Log.println('Unable to find function ${fnName}');
						}
						vm.STR.setStringValue("");
					}
					switch (nsEntry.type) {
						case ScriptFunctionType(functionOffset, codeBlock):
							if (functionOffset != 0) codeBlock.exec(functionOffset, fnName, nsEntry.namespace, callArgs, false,
								nsEntry.pkg); else vm.STR.setStringValue("");

						case x:
							if ((nsEntry.minArgs > 0 && callArgs.length < nsEntry.minArgs)
								|| (nsEntry.maxArgs > 0 && callArgs.length > nsEntry.maxArgs)) {
								Log.println('Invalid argument count for function ${fnName}');
							} else {
								switch (x) {
									case StringCallbackType(callback):
										var ret = callback(vm, vm.evalState.thisObject, callArgs);
										if (ret != vm.STR.getSTValue()) vm.STR.setStringValue(ret);

									case IntCallbackType(callback):
										var ret = callback(vm, vm.evalState.thisObject, callArgs);
										if (codeStream[ip] == cast OpCode.StrToUInt) {
											ip++;
											vm.intStack.add(ret);
										} else if (codeStream[ip] == cast OpCode.StrToFlt) {
											ip++;
											vm.floatStack.add(ret);
										} else if (codeStream[ip] == cast OpCode.StrToNone) {
											ip++;
										} else vm.STR.setIntValue(ret);

									case FloatCallbackType(callback):
										var ret = callback(vm, vm.evalState.thisObject, callArgs);
										if (codeStream[ip] == cast OpCode.StrToUInt) {
											ip++;
											vm.intStack.add(cast ret);
										} else if (codeStream[ip] == cast OpCode.StrToFlt) {
											ip++;
											vm.floatStack.add(ret);
										} else if (codeStream[ip] == cast OpCode.StrToNone) {
											ip++;
										} else vm.STR.setFloatValue(ret);

									case VoidCallbackType(callback):
										callback(vm, vm.evalState.thisObject, callArgs);
										if (codeStream[ip] != cast OpCode.StrToNone) {
											Log.println('Call to ${fnName} uses result of void function call');
										}
										vm.STR.setStringValue("");

									case BoolCallbackType(callback):
										var ret = callback(vm, vm.evalState.thisObject, callArgs);
										if (codeStream[ip] == cast OpCode.StrToUInt) {
											ip++;
											vm.intStack.add(cast ret);
										} else if (codeStream[ip] == cast OpCode.StrToFlt) {
											ip++;
											vm.floatStack.add(cast ret);
										} else if (codeStream[ip] == cast OpCode.StrToNone) {
											ip++;
										} else vm.STR.setIntValue(cast ret);

									case ScriptFunctionType(_, _):
										false; // Bruh we cant reach here
								}
							}

							if (callType == cast MethodCall) vm.evalState.thisObject = saveObj;
					}

				case OpCode.ProcessArgs:
					false; // Do nothing

				case OpCode.AdvanceStr:
					vm.STR.advance();

				case OpCode.AdvanceStrAppendChar:
					vm.STR.advanceChar(codeStream[ip++]);

				case OpCode.AdvanceStrComma:
					vm.STR.advanceChar('_'.charCodeAt(0));

				case OpCode.AdvanceStrNul:
					vm.STR.advanceChar(0);

				case OpCode.RewindStr:
					vm.STR.rewind();

				case OpCode.TerminateRewindStr:
					vm.STR.rewindTerminate();

				case OpCode.CompareStr:
					vm.intStack.add(cast vm.STR.compare());

				case OpCode.Push:
					vm.STR.push();

				case OpCode.PushFrame:
					vm.STR.pushFrame();

				case OpCode.Break:
					breakContinue = true;
					breakContinueIns = instruction;

				case OpCode.Invalid:
					break; // Execfinished
			}
		}

		if (fnArgs.length != 0) {
			vm.evalState.popFrame();

			if (vm.traceOn) {
				Log.print("Leaving ");
				if (packageName != null) {
					Log.print('[${packageName}] ');
				}
				if (namespace != null && namespace.name != null) {
					Log.println('${namespace.name}::${thisFunctionName}() - return ${vm.STR.getSTValue()}');
				} else {
					Log.println('${thisFunctionName}() - return ${vm.STR.getSTValue()}');
				}
			}
		}

		return vm.STR.getSTValue();
	}
}
