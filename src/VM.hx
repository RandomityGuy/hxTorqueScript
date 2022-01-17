package;

import sys.io.File;
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
			Sys.println("Warning: Undefined variable '" + name + "'");
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
			Sys.println("Warning: Accessing local variable '" + name + "' in global scope!");
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

	var nextSimId = 2000;
	var nextDatablockId = 1;

	var activePackages:Array<String> = [];

	var codeBlocks:Array<CodeBlock> = [];

	public function new() {
		evalState = new ExprEvalState(this);

		this.namespaces.push(new Namespace(null, null, null));

		ConsoleFunctions.install(this);
		ConsoleObjectConstructors.install(this);

		rootGroup.register(this);
	}

	public function exec(path:String) {
		var code = new CodeBlock(this, path);
		code.load(new BytesInput(File.getBytes(path)));
		code.exec(0, null, null, [], false, null);
		if (code.addedFunctions)
			codeBlocks.push(code);
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

	public function findObject(name:String) {
		return simObjects.exists(name) ? simObjects.get(name) : (idMap.exists(Std.parseInt(name)) ? idMap.get(Std.parseInt(name)) : null);
	}
}
