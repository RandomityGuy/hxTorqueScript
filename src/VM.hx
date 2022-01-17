package;

import console.Namespace.FunctionType;
import console.ConsoleFunctions;
import Compiler.IdentTable;
import haxe.Exception;
import haxe.io.BytesInput;
import expr.Expr.FuncCallExpr;
import expr.Expr.FuncCallType;
import console.Namespace.NamespaceEntry;
import console.SimSet;
import console.SimGroup;
import sys.net.Address;
import console.ConsoleObjectConstructors;
import console.SimDataBlock;
import console.SimObject;
import expr.OpCode;
import haxe.ds.GenericStack;
import haxe.io.Bytes;
import console.Namespace.Namespace;

class BytesExtensions {
	public static function strlen(b:Bytes, start:Int) {
		var slen = 0;
		while (b.get(start) != 0) {
			start++;
			slen++;
		}
		return slen;
	}

	public static function getBytes(s:String) {
		var bytes = Bytes.alloc(s.length + 1);
		for (i in 0...s.length) {
			bytes.set(i, s.charCodeAt(i));
		}
		bytes.set(s.length, 0);
		return bytes;
	}

	public static function getString(buffer:Bytes, start:Int) {
		var sbuf = new StringBuf();
		var i = start;
		while (buffer.get(i) != 0) {
			sbuf.addChar(buffer.get(i));
			i++;
		}
		return sbuf.toString();
	}
}

class StringStack {
	var buffer:Bytes;
	var bufferSize:Int;
	var argv:Array<String>;
	var frameOffsets:Array<Int> = [];
	var startOffsets:Array<Int> = [];

	var numFrames:Int = 0;
	var argc:Int = 0;

	var start:Int = 0;
	var len:Int = 0;
	var startStackSize:Int = 0;
	var functionOffset:Int = 0;

	var argBuffer:Bytes;
	var argBufferSize:Int;

	public function new() {
		bufferSize = 0;
		buffer = Bytes.alloc(1024);
		numFrames = 0;
		start = 0;
		len = 0;
		startStackSize = 0;
		functionOffset = 0;
		for (i in 0...1024) {
			frameOffsets.push(0);
			startOffsets.push(0);
		}
		validateBufferSize(8092);
		validateArgBufferSize(2048);
	}

	function validateBufferSize(size:Int) {
		if (size > bufferSize) {
			bufferSize = size + 2048;
			var newbuf = Bytes.alloc(bufferSize);
			newbuf.blit(0, buffer, 0, buffer.length);
			buffer = newbuf;
		}
	}

	function validateArgBufferSize(size:Int) {
		if (size > bufferSize) {
			argBufferSize = size + 2048;
			var newbuf = Bytes.alloc(argBufferSize);
			newbuf.blit(0, argBuffer, 0, argBuffer.length);
			argBuffer = newbuf;
		}
	}

	public function setIntValue(i:Int) {
		validateBufferSize(start + 32);
		var s = BytesExtensions.getBytes('${i}');
		buffer.blit(start, s, 0, s.length);
		len = s.length - 1;
	}

	public function setFloatValue(i:Float) {
		validateBufferSize(start + 32);
		var s = BytesExtensions.getBytes('${i}');
		buffer.blit(start, s, 0, s.length);
		len = s.length - 1;
	}

	public function clearFunctionOffset() {
		functionOffset = 0;
	}

	public function setStringValue(s:String) {
		if (s == null) {
			len = 0;
			buffer.set(start, 0);
			return;
		}
		var sbuf = BytesExtensions.getBytes(s);
		len = sbuf.length - 1;
		validateBufferSize(start + len + 2);
		buffer.blit(start, sbuf, 0, sbuf.length);
	}

	public function getSTValue() {
		var sbuf = new StringBuf();
		var i = start;
		while (buffer.get(i) != 0) {
			sbuf.addChar(buffer.get(i));
			i++;
		}
		return sbuf.toString();
	}

	public function getIntValue() {
		var s = getSTValue();
		return Std.parseInt(s);
	}

	public function getFloatValue() {
		var s = getSTValue();
		return Std.parseFloat(s);
	}

	public function advance() {
		startOffsets[startStackSize++] = start;
		start += len;
		len = 0;
	}

	public function advanceChar(c:Int) {
		startOffsets[startStackSize++] = start;
		start += len;
		buffer.set(start, c);
		buffer.set(start + 1, 0);
		start += 1;
		len = 0;
	}

	public function push() {
		advanceChar(0);
	}

	public function setLen(newLen:Int) {
		len = newLen;
	}

	public function rewind() {
		start = startOffsets[--startStackSize];
		len = BytesExtensions.strlen(buffer, start);
	}

	public function rewindTerminate() {
		buffer.set(start, 0);
		start = startOffsets[--startStackSize];
		len = BytesExtensions.strlen(buffer, start);
	}

	public function compare() {
		var oldStart = start;
		start = startOffsets[--startStackSize];

		var ret = (BytesExtensions.getString(buffer, start).toLowerCase() == BytesExtensions.getString(buffer, oldStart).toLowerCase());
		len = 0;
		buffer.set(start, 0);
		return ret;
	}

	public function pushFrame() {
		frameOffsets[numFrames++] = startStackSize;
		startOffsets[startStackSize++] = start;
		start += 512;
		validateBufferSize(0);
	}

	public function getArgs(name:String) {
		var startStack = frameOffsets[--numFrames] + 1;
		var argCount:Int = cast Math.min(startStackSize - startStack, 20);
		var args = [name];
		for (i in 0...argCount)
			args.push(BytesExtensions.getString(buffer, startOffsets[startStack + i]));
		argCount++;
		startStackSize = startStack - 1;
		start = startOffsets[startStackSize];
		len = 0;
		return args;
	}
}

class Variable {
	var name:String;
	var intValue:Int;
	var floatValue:Float;
	var stringValue:String;

	var vm:VM;

	var internalType:Int = -1; // -3 = int, -2 = float, -1 = string

	public function new(name:String, vm:VM) {
		this.name = name;
		this.vm = vm;
	}

	public function getIntValue() {
		if (internalType < -1) {
			return intValue;
		} else {
			if (vm.simObjects.exists(stringValue))
				return vm.simObjects.get(stringValue).id;
			var intParse = Std.parseInt(stringValue);
			if (intParse == null)
				return 0;
			else
				return intParse;
		}
	}

	public function getFloatValue() {
		if (internalType < -1) {
			return floatValue;
		} else {
			if (vm.simObjects.exists(stringValue))
				return vm.simObjects.get(stringValue).id;
			var floatParse = Std.parseFloat(stringValue);
			if (Math.isNaN(floatParse))
				return 0;
			else
				return floatParse;
		}
	}

	public function getStringValue() {
		if (internalType == -1)
			return stringValue;
		if (internalType == -2)
			return Std.string(floatValue);
		if (internalType == -3)
			return Std.string(intValue);
		else
			return stringValue;
	}

	public function setIntValue(val:Int) {
		if (internalType < -1) {
			intValue = val;
			floatValue = cast intValue;
			stringValue = null;
			internalType = -3;
		} else {
			intValue = val;
			floatValue = cast intValue;
			stringValue = Std.string(val);
		}
	}

	public function setFloatValue(val:Float) {
		if (internalType < -1) {
			floatValue = val;
			intValue = cast floatValue;
			stringValue = null;
			internalType = -2;
		} else {
			floatValue = val;
			intValue = cast floatValue;
			stringValue = Std.string(val);
		}
	}

	public function setStringValue(val:String) {
		if (internalType < -1) {
			floatValue = Std.parseFloat(val);
			intValue = cast floatValue;
			internalType = -1;
			stringValue = val;
		} else {
			floatValue = Std.parseFloat(val);
			intValue = cast floatValue;
			stringValue = val;
		}
	}
}

typedef StackFrame = {
	var scopeName:String;
	var scopeNamespace:Namespace;
}

@:publicFields
class ExprEvalState {
	var thisObject:SimObject;
	var thisVariable:Variable;

	var globalVars:Map<String, Variable>;
	var stackVars:Array<Map<String, Variable>>;

	var stack:Array<StackFrame>;

	var vm:VM;

	public function new(vm:VM) {
		globalVars = new Map<String, Variable>();
		thisObject = null;
		thisVariable = null;
		stack = [];
		stackVars = [];
		this.vm = vm;
	}

	public function setCurVarName(name:String) {
		if (name.charAt(0) == "$")
			thisVariable = globalVars.get(name);
		else if (stackVars.length > 0)
			thisVariable = stackVars[stackVars.length - 1].get(name);
		if (thisVariable == null)
			trace("Warning: Undefined variable '" + name + "'");
	}

	public function setCurVarNameCreate(name:String) {
		if (name.charAt(0) == "$") {
			if (this.globalVars.exists(name))
				thisVariable = this.globalVars.get(name);
			else {
				thisVariable = new Variable(name, vm);
				globalVars.set(name, thisVariable);
			}
		} else if (stackVars.length > 0) {
			if (stackVars[stackVars.length - 1].exists(name))
				thisVariable = stackVars[stackVars.length - 1].get(name);
			else {
				thisVariable = new Variable(name, vm);
				stackVars[stackVars.length - 1].set(name, thisVariable);
			}
		} else {
			thisVariable = null;
			trace("Warning: Accessing local variable '" + name + "' in global scope!");
		}
	}

	public function getIntVariable() {
		return thisVariable != null ? thisVariable.getIntValue() : 0;
	}

	public function getFloatVariable() {
		return thisVariable != null ? thisVariable.getFloatValue() : 0;
	}

	public function getStringVariable() {
		return thisVariable != null ? thisVariable.getStringValue() : "";
	}

	public function setIntVariable(val:Int) {
		if (thisVariable != null)
			thisVariable.setIntValue(val);
	}

	public function setFloatVariable(val:Float) {
		if (thisVariable != null)
			thisVariable.setFloatValue(val);
	}

	public function setStringVariable(val:String) {
		if (thisVariable != null)
			thisVariable.setStringValue(val);
	}

	public function pushFrame(fnname:String, namespace:Namespace) {
		var f:StackFrame = {
			scopeName: fnname,
			scopeNamespace: namespace
		};
		stack.push(f);
		stackVars.push(new Map());
	}

	public function popFrame() {
		stack.pop();
		stackVars.pop();
	}
}

@:publicFields
class VM {
	var globalFloatTable:Array<Float> = [];
	var functionFloatTable:Array<Float> = [];
	var globalStringTable:String;
	var functionStringTable:String;

	var codeStream:Array<Int> = [];
	var lineBreakPairs:Array<Int> = [];

	var inFunction:Bool = false;

	var opCodeLookup:Map<Int, String> = [];

	public var namespaces:Array<Namespace> = [];

	var STR:StringStack = new StringStack();

	var floatStack:GenericStack<Float> = new GenericStack();

	var intStack:GenericStack<Int> = new GenericStack();

	var evalState:ExprEvalState;

	var taggedStrings:Array<String> = [];

	var simObjects:Map<String, SimObject> = new Map<String, SimObject>();

	var dataBlocks:Map<String, SimDataBlock> = new Map<String, SimDataBlock>();

	var idMap:Map<Int, SimObject> = new Map<Int, SimObject>();

	var rootGroup:SimGroup = new SimGroup();

	var resolveFuncId:Int = 0;

	var resolveFuncMap:Map<Int, NamespaceEntry> = new Map<Int, NamespaceEntry>();

	var dsoVersion:Int;

	var identMap:Map<Int, String> = [0 => null];
	var identMapSize = 1;

	var nextSimId = 2000;
	var nextDatablockId = 1;

	var activePackages:Array<String> = [];

	public function new() {
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

		evalState = new ExprEvalState(this);

		this.namespaces.push(new Namespace(null, null, null));

		ConsoleFunctions.install(this);
		ConsoleObjectConstructors.install(this);

		rootGroup.register(this);
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

	public function findNamespace(name:String) {
		var nsList = this.namespaces.filter(x -> x.name != null ? (x.name.toLowerCase() == name.toLowerCase()) : x.name == name);
		if (nsList.length == 0)
			return null;
		return nsList[0];
	}

	public function findFunction(namespace:String, name:String) {
		var pkgs = activePackages.copy();
		pkgs.reverse();
		pkgs.push(null);
		var nmcmp = namespace == null ? null : namespace.toLowerCase();
		for (pkg in pkgs) {
			for (nm in namespaces) {
				if (nm.pkg == pkg) {
					var thisnm = nm.name == null ? null : nm.name.toLowerCase();
					if (thisnm == nmcmp) {
						var f = nm.find(name);
						if (f != null)
							return f;
					}
				}
			}
		}
		return null;
	}

	public function linkNamespaces(parent:String, child:String) {
		var parentNamespace = findNamespace(parent);
		if (parentNamespace == null) {
			parentNamespace = new Namespace(parent, null, null);
			this.namespaces.push(parentNamespace);
		}
		var childNamespace = findNamespace(child);
		if (childNamespace == null) {
			childNamespace = new Namespace(child, null, null);
			this.namespaces.push(childNamespace);
		}
		childNamespace.parent = parentNamespace;
	}

	public function activatePackage(name:String) {
		var lastActivePackage = this.activePackages.length == 0 ? null : this.activePackages[this.activePackages.length - 1];
		for (namespace in namespaces) {
			if (namespace.pkg == name) {
				// Gonna have to find the same namespace in the last active package
				var prevNamespace = namespaces.filter(x -> x.name == namespace.name && x.pkg == lastActivePackage)[0];
				namespace.parent = prevNamespace;
			}
		}
		this.activePackages.push(name);
	}

	public function deactivatePackage(name:String) {
		var referencingNamespaces = [];

		for (namespace in namespaces) {
			if (namespace.parent != null) {
				if (namespace.parent.pkg == name) {
					referencingNamespaces.push(namespace);
				}
			}
			if (namespace.pkg == name) {
				namespace.parent = null;
			}
		}

		var prevPackages = this.activePackages.slice(0, this.activePackages.indexOf(name));
		prevPackages.reverse();
		prevPackages.push(null);
		this.activePackages.remove(name);
		for (namespace in referencingNamespaces) {
			var parentNamespace:Namespace = null;
			for (prevPackage in prevPackages) {
				var lastNamespace = namespaces.filter(x -> x.name == namespace.name && x.pkg == prevPackage)[0];
				if (lastNamespace != null) {
					parentNamespace = lastNamespace;
					break;
				}
			}
			namespace.parent = parentNamespace;
		}
	}

	public function addConsoleFunction(fnName:String, fnUsage:String, minArgs:Int, maxArgs:Int, fnType:FunctionType) {
		var emptyNamespace = namespaces[0]; // The root namespace, guaranteed
		emptyNamespace.addFunctionFull(fnName, fnUsage, minArgs, maxArgs, fnType);
	}

	public function addConsoleMethod(className:String, fnName:String, fnUsage:String, minArgs:Int, maxArgs:Int, fnType:FunctionType) {
		var findNamespaces = findNamespace(className);
		var namespace:Namespace = null;
		if (findNamespaces == null) {
			namespace = new Namespace(className, null, null);
			namespaces.push(namespace);
		} else {
			namespace = findNamespaces;
		}
		namespace.addFunctionFull(fnName, fnUsage, minArgs, maxArgs, fnType);
	}

	function getStringTableValue(table:String, offset:Int) {
		return table.substr(offset, table.indexOf("\x00", offset) - offset);
	}

	public function findObject(name:String) {
		return simObjects.exists(name) ? simObjects.get(name) : (idMap.exists(Std.parseInt(name)) ? idMap.get(Std.parseInt(name)) : null);
	}

	public function exec(ip:Int, functionName:Null<String>, namespace:Namespace, fnArgs:Array<String>, noCalls:Bool, packageName:String) {
		var currentStringTable:String = null;
		var currentFloatTable:Array<Float> = null;

		STR.clearFunctionOffset();
		var thisFunctionName:String = null;
		var argc = fnArgs.length;
		if (fnArgs.length != 0) {
			var fnArgc = codeStream[ip + 5];
			thisFunctionName = identMap.get(codeStream[ip]);
			argc = cast Math.min(fnArgs.length - 1, fnArgc);
			evalState.pushFrame(thisFunctionName, namespace);
			for (i in 0...argc) {
				var varName = identMap.get(codeStream[ip + 6 + i]);
				evalState.setCurVarNameCreate(varName);
				evalState.setStringVariable(fnArgs[i + 1]);
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
						for (n in this.namespaces) {
							if (n.name == fnNamespace && n.pkg == pkg) {
								nmspc = n;
								break;
							}
						}
						if (nmspc == null) {
							nmspc = new Namespace(fnNamespace, pkg, null);
							this.namespaces.push(nmspc);
						}
						nmspc.addFunction(fnName, hasBody ? ip : 0);
					}
					ip = codeStream[ip + 4];

				case OpCode.CreateObject:
					if (noCalls) {
						ip = failJump;
					}
					objParent = identMap.get(codeStream[ip]);
					var datablock = codeStream[ip + 1] == 1;
					failJump = codeStream[ip + 2];
					callArgs = STR.getArgs("");

					currentNewObject = null;
					if (datablock) {
						var db:SimObject = this.dataBlocks.get(callArgs[2]);
						if (db != null) {
							if (db.getClassName().toLowerCase() == callArgs[1].toLowerCase()) {
								trace('Cannot re-declare data block ${callArgs[1]} with a different class.');
								ip = failJump;
								continue;
							}
							currentNewObject = db;
						}
					}
					if (currentNewObject == null) {
						if (!ConsoleObjectConstructors.constructorMap.exists(callArgs[1])) {
							trace('Unable to instantantiate non con-object class ${callArgs[1]}');
							ip = failJump;
							continue;
						}
						currentNewObject = cast ConsoleObjectConstructors.constructorMap.get(callArgs[1])();
						currentNewObject.assignId(datablock ? nextDatablockId++ : nextSimId++);
						if (objParent != null) {
							var parent = this.simObjects.get(objParent);
							if (parent != null) {
								currentNewObject.assignFieldsFrom(parent);
							} else {
								trace('Parent object ${objParent} for ${callArgs[1]} does not exist.');
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
					if (!this.simObjects.exists(currentNewObject.name)) {
						added = true;
						this.simObjects.set(currentNewObject.getName(), currentNewObject);
					}
					this.idMap.set(currentNewObject.id, currentNewObject);
					currentNewObject.register(this);

					var datablock:SimDataBlock = Std.isOfType(currentNewObject, SimDataBlock) ? cast currentNewObject : null;
					if (datablock != null) {
						if (!datablock.preload()) {
							trace('Datablock ${datablock.getName()} failed to preload.');
							ip = failJump;
							this.idMap.remove(currentNewObject.id);
							if (added)
								this.simObjects.remove(currentNewObject.getName());
							continue;
						} else {
							this.dataBlocks.set(currentNewObject.getName(), datablock);
						}
					}
					var groupAddId = intStack.first();
					if (!root || currentNewObject.group == null) {
						if (root) {
							rootGroup.addObject(currentNewObject);
						} else {
							if (idMap.get(groupAddId) != null) {
								if (Std.isOfType(currentNewObject, SimGroup) || Std.isOfType(currentNewObject, SimSet))
									cast(idMap.get(groupAddId), SimSet).addObject(currentNewObject);
								else {
									rootGroup.addObject(currentNewObject);
								}
							} else {
								rootGroup.addObject(currentNewObject);
							}
						}
					}
					if (root) {
						intStack.pop();
					}
					intStack.add(currentNewObject.id);

				case OpCode.EndObject:
					var root = codeStream[ip++] > 0;
					if (!root)
						intStack.pop();

				case OpCode.JmpIffNot:
					if (floatStack.pop() > 0) {
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIfNot:
					if (intStack.pop() > 0) {
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIff:
					if (floatStack.pop() <= 0) {
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIf:
					if (intStack.pop() <= 0) {
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIfNotNP:
					if (intStack.first() > 0) {
						intStack.pop();
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.JmpIfNP:
					if (intStack.first() <= 0) {
						intStack.pop();
						ip++;
					} else {
						ip = codeStream[ip];
					}

				case OpCode.Jmp:
					ip = codeStream[ip];

				case OpCode.Return:
					break;

				case OpCode.CmpEQ:
					intStack.add(floatStack.pop() == floatStack.pop() ? 1 : 0);

				case OpCode.CmpGT:
					intStack.add(floatStack.pop() > floatStack.pop() ? 1 : 0);

				case OpCode.CmpGE:
					intStack.add(floatStack.pop() >= floatStack.pop() ? 1 : 0);

				case OpCode.CmpLT:
					intStack.add(floatStack.pop() < floatStack.pop() ? 1 : 0);

				case OpCode.CmpLE:
					intStack.add(floatStack.pop() <= floatStack.pop() ? 1 : 0);

				case OpCode.CmpNE:
					intStack.add(floatStack.pop() != floatStack.pop() ? 1 : 0);

				case OpCode.Xor:
					intStack.add(intStack.pop() ^ intStack.pop());

				case OpCode.Mod:
					intStack.add(intStack.pop() % intStack.pop());

				case OpCode.BitAnd:
					intStack.add(intStack.pop() & intStack.pop());

				case OpCode.BitOr:
					intStack.add(intStack.pop() | intStack.pop());

				case OpCode.Not:
					intStack.add(intStack.pop() > 0 ? 0 : 1);

				case OpCode.NotF:
					intStack.add(floatStack.pop() > 0 ? 0 : 1);

				case OpCode.OnesComplement:
					intStack.add(~intStack.pop());

				case OpCode.Shl:
					intStack.add(cast intStack.pop() << intStack.pop());

				case OpCode.Shr:
					intStack.add(cast intStack.pop() >> intStack.pop());

				case OpCode.And:
					intStack.add(cast intStack.pop() > 0 && intStack.pop() > 0);

				case OpCode.Or:
					intStack.add(cast intStack.pop() > 0 || intStack.pop() > 0);

				case OpCode.Add:
					floatStack.add(floatStack.pop() + floatStack.pop());

				case OpCode.Sub:
					floatStack.add(floatStack.pop() - floatStack.pop());

				case OpCode.Mul:
					floatStack.add(floatStack.pop() * floatStack.pop());

				case OpCode.Div:
					floatStack.add(floatStack.pop() / floatStack.pop());

				case OpCode.Neg:
					floatStack.add(-floatStack.pop());

				case OpCode.SetCurVar:
					var varName = identMap.get(codeStream[ip++]);
					evalState.setCurVarName(varName);

				case OpCode.SetCurVarCreate:
					var varName = identMap.get(codeStream[ip++]);
					evalState.setCurVarNameCreate(varName);

				case OpCode.SetCurVarArray:
					var varName = this.STR.getSTValue();
					evalState.setCurVarName(varName);

				case OpCode.SetCurVarArrayCreate:
					var varName = this.STR.getSTValue();
					evalState.setCurVarNameCreate(varName);

				case OpCode.LoadVarUInt:
					intStack.add(evalState.getIntVariable());

				case OpCode.LoadVarFlt:
					floatStack.add(evalState.getFloatVariable());

				case OpCode.LoadVarStr:
					STR.setStringValue(evalState.getStringVariable());

				case OpCode.SaveVarUInt:
					evalState.setIntVariable(intStack.first());

				case OpCode.SaveVarFlt:
					evalState.setFloatVariable(floatStack.first());

				case OpCode.SaveVarStr:
					evalState.setStringVariable(STR.getSTValue());

				case OpCode.SetCurObject:
					curObject = simObjects.get(STR.getSTValue());
					if (curObject == null)
						curObject = idMap.get(Std.parseInt(STR.getSTValue()));

				case OpCode.SetCurObjectNew:
					curObject = currentNewObject;

				case OpCode.SetCurField:
					curField = identMap.get(codeStream[ip++]);
					curFieldArrayIndex = null;

				case OpCode.SetCurFieldArray:
					curFieldArrayIndex = STR.getSTValue();

				case OpCode.LoadFieldUInt:
					if (curObject != null)
						intStack.add(cast Std.parseFloat(curObject.getDataField(curField, curFieldArrayIndex)));
					else
						intStack.add(0);

				case OpCode.LoadFieldFlt:
					if (curObject != null)
						floatStack.add(Std.parseFloat(curObject.getDataField(curField, curFieldArrayIndex)));
					else
						floatStack.add(0);

				case OpCode.LoadFieldStr:
					if (curObject != null)
						STR.setStringValue(curObject.getDataField(curField, curFieldArrayIndex));
					else
						STR.setStringValue("");

				case OpCode.SaveFieldUInt:
					STR.setIntValue(intStack.first());
					if (curObject != null)
						curObject.setDataField(curField, curFieldArrayIndex, STR.getSTValue());

				case OpCode.SaveFieldFlt:
					STR.setFloatValue(floatStack.first());
					if (curObject != null)
						curObject.setDataField(curField, curFieldArrayIndex, STR.getSTValue());

				case OpCode.SaveFieldStr:
					if (curObject != null)
						curObject.setDataField(curField, curFieldArrayIndex, STR.getSTValue());

				case OpCode.StrToUInt:
					intStack.add(STR.getIntValue());

				case OpCode.StrToFlt:
					floatStack.add(STR.getFloatValue());

				case OpCode.StrToNone:
					false;

				case OpCode.FltToUInt:
					intStack.add(cast floatStack.pop());

				case OpCode.FltToStr:
					STR.setFloatValue(floatStack.pop());

				case OpCode.FltToNone:
					floatStack.pop();

				case OpCode.UIntToFlt:
					floatStack.add(intStack.pop());

				case OpCode.UIntToStr:
					STR.setIntValue(intStack.pop());

				case OpCode.UIntToNone:
					intStack.pop();

				case OpCode.LoadImmedUInt:
					intStack.add(codeStream[ip++]);

				case OpCode.LoadImmedFlt:
					floatStack.add(currentFloatTable[codeStream[ip++]]);

				case OpCode.TagToStr:
					codeStream[ip - 1] = cast OpCode.LoadImmedStr;
					if (getStringTableValue(currentStringTable, codeStream[ip]).charCodeAt(0) != 1) {
						var id = this.taggedStrings.length;
						this.taggedStrings.push(getStringTableValue(currentStringTable, codeStream[ip]));
						codeStream[ip] = 1; // StringTagPrefixByte
						var idStr = '${id}';
						if (idStr.length < 7) {
							for (i in 0...idStr.length) {
								codeStream[ip + 1 + i] = idStr.charCodeAt(i);
							}
							for (i in idStr.length...7) {
								codeStream[ip + 1 + i] = 0;
							}
						} else {
							for (i in 0...7) {
								codeStream[ip + 1 + i] = idStr.charCodeAt(i);
							}
						}
					}

				case OpCode.LoadImmedStr:
					STR.setStringValue(getStringTableValue(currentStringTable, codeStream[ip++]));

				case OpCode.LoadImmedIdent:
					STR.setStringValue(identMap.get(codeStream[ip++]));

				case OpCode.CallFuncResolve:
					var fnNamespace = identMap.get(codeStream[ip + 1]);
					var fnName = identMap.get(codeStream[ip]);
					var nsEntry = findFunction(fnNamespace, fnName);
					if (nsEntry == null) {
						ip += 3;
						trace('Unable to find function ${fnNamespace}::${fnName}');
						STR.getArgs(fnName);
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
					callArgs = STR.getArgs(fnName);
					var nsEntry:NamespaceEntry = null;
					var ns:Namespace = null;
					if (callType == cast FuncCallType.FunctionCall) {
						nsEntry = this.resolveFuncMap.get(codeStream[ip - 2]);
					} else if (callType == cast FuncCallType.MethodCall) {
						saveObj = evalState.thisObject;
						evalState.thisObject = simObjects.get(callArgs[1]);
						if (evalState.thisObject == null)
							evalState.thisObject = idMap.get(Std.parseInt(callArgs[1]));
						if (evalState.thisObject == null) {
							trace('Unable to find object ${callArgs[1]} attempting to call function ${fnName}');
							continue;
						}
						nsEntry = this.findFunction(evalState.thisObject.getClassName(), fnName);
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
							trace('Unable to find function ${fnName}');
						}
						STR.setStringValue("");
					}
					switch (nsEntry.type) {
						case ScriptFunctionType(functionOffset):
							if (functionOffset != 0) this.exec(functionOffset, fnName, nsEntry.namespace, callArgs, false,
								nsEntry.pkg); else STR.setStringValue("");

						case x:
							if ((nsEntry.minArgs > 0 && callArgs.length < nsEntry.minArgs)
								|| (nsEntry.maxArgs > 0 && callArgs.length > nsEntry.maxArgs)) {
								trace('Invalid argument count for function ${fnName}');
							} else {
								switch (x) {
									case StringCallbackType(callback):
										var ret = callback(this, evalState.thisObject, callArgs);
										if (ret != STR.getSTValue()) STR.setStringValue(ret);

									case IntCallbackType(callback):
										var ret = callback(this, evalState.thisObject, callArgs);
										if (codeStream[ip] == cast OpCode.StrToUInt) {
											ip++;
											intStack.add(ret);
										} else if (codeStream[ip] == cast OpCode.StrToFlt) {
											ip++;
											floatStack.add(ret);
										} else if (codeStream[ip] == cast OpCode.StrToNone) {
											ip++;
										} else STR.setIntValue(ret);

									case FloatCallbackType(callback):
										var ret = callback(this, evalState.thisObject, callArgs);
										if (codeStream[ip] == cast OpCode.StrToUInt) {
											ip++;
											intStack.add(cast ret);
										} else if (codeStream[ip] == cast OpCode.StrToFlt) {
											ip++;
											floatStack.add(ret);
										} else if (codeStream[ip] == cast OpCode.StrToNone) {
											ip++;
										} else STR.setFloatValue(ret);

									case VoidCallbackType(callback):
										callback(this, evalState.thisObject, callArgs);
										if (codeStream[ip] != cast OpCode.StrToNone) {
											trace('Call to ${fnName} uses result of void function call');
										}
										STR.setStringValue("");

									case BoolCallbackType(callback):
										var ret = callback(this, evalState.thisObject, callArgs);
										if (codeStream[ip] == cast OpCode.StrToUInt) {
											ip++;
											intStack.add(cast ret);
										} else if (codeStream[ip] == cast OpCode.StrToFlt) {
											ip++;
											floatStack.add(cast ret);
										} else if (codeStream[ip] == cast OpCode.StrToNone) {
											ip++;
										} else STR.setIntValue(cast ret);

									case ScriptFunctionType(functionOffset):
										false; // Bruh we cant reach here
								}
							}

							if (callType == cast MethodCall) evalState.thisObject = saveObj;
					}

				case OpCode.ProcessArgs:
					false; // Do nothing

				case OpCode.AdvanceStr:
					STR.advance();

				case OpCode.AdvanceStrAppendChar:
					STR.advanceChar(codeStream[ip++]);

				case OpCode.AdvanceStrComma:
					STR.advanceChar('_'.charCodeAt(0));

				case OpCode.AdvanceStrNul:
					STR.advanceChar(0);

				case OpCode.RewindStr:
					STR.rewind();

				case OpCode.TerminateRewindStr:
					STR.rewindTerminate();

				case OpCode.CompareStr:
					intStack.add(cast STR.compare());

				case OpCode.Push:
					STR.push();

				case OpCode.PushFrame:
					STR.pushFrame();

				case OpCode.Break:
					breakContinue = true;
					breakContinueIns = instruction;

				case OpCode.Invalid:
					break; // Execfinished
			}
		}
	}
}
