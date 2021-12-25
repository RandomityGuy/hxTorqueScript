package;

import haxe.io.BytesInput;
import expr.OpCode;
import haxe.Exception;
import expr.Expr.Stmt;
import haxe.ds.Vector;
import haxe.io.BytesData;
import haxe.io.BytesBuffer;
import hl.Bytes;

enum ConstTable {
	StringTable;
	FloatTable;
}

enum ConstTableType {
	Global;
	Function;
}

typedef StringTableEntry = {
	var string:String;
	var start:Int;
	var len:Int;
	var tag:Bool;
};

class StringTable {
	var totalLen:Int;

	public var entries:Array<StringTableEntry> = [];

	public function new() {}

	public function add(str:String, caseSens:Bool, tag:Bool) {
		for (e in entries) {
			if (e.tag != tag)
				continue;

			if (str == "" && e.string == "") // Because fuck it, apparently this bugs out otherwise.
				return e.start;
			else {
				if (!caseSens) {
					if (str.toLowerCase() == e.string.toLowerCase())
						return e.start;
				} else if (str == e.string)
					return e.start;
			}
		}

		var len = str.length + 1;
		if (tag && len < 7) {
			len = 7;
		}

		var addEntry:StringTableEntry = {
			start: totalLen,
			len: len,
			string: str,
			tag: tag
		}

		entries.push(addEntry);

		totalLen += len;

		return addEntry.start;
	}

	public function write(bytesData:BytesBuffer) {
		bytesData.addInt32(totalLen);
		for (entry in entries) {
			for (c in 0...entry.string.length) {
				bytesData.addByte(entry.string.charCodeAt(c));
			}
			bytesData.addByte(0); // The null terminator
			if (entry.len > entry.string.length) { // Well gotta pad the shit with zeros
				for (i in 0...entry.len - entry.string.length - 1) {
					bytesData.addByte(0);
				}
			}
		}
	}

	public function read(bytesInput:BytesInput) {
		totalLen = bytesInput.readInt32();
		var currentStr = "";
		var curStrLen = 0;
		var curStrStart = 0;
		for (i in 0...totalLen) {
			var c = bytesInput.readByte();
			if (c == 0) {
				var entry = {
					start: curStrStart,
					len: curStrLen + 1,
					string: currentStr,
					tag: false
				}
				curStrLen = 0;
				currentStr = "";
				curStrStart = i + 1;
				this.entries.push(entry);
			} else {
				currentStr += String.fromCharCode(c);
				curStrLen++;
			}
		}
	}
}

class IdentTable {
	public var identMap:Map<Int, Array<Int>> = [];

	public function new() {}

	public function add(compiler:Compiler, ste:String, ip:Int) {
		var index = compiler.globalStringTable.add(ste, false, false);

		if (identMap.exists(index)) {
			identMap.get(index).push(ip);
		} else {
			identMap.set(index, [ip]);
		}
	}

	public function write(bytesData:BytesBuffer) {
		var count = 0;
		for (kv in identMap)
			count++;
		bytesData.addInt32(count);
		for (kv in identMap.keyValueIterator()) {
			bytesData.addInt32(kv.key);
			bytesData.addInt32(kv.value.length);
			for (i in kv.value)
				bytesData.addInt32(i);
		}
	}

	public function read(bytesInput:BytesInput) {
		var count = bytesInput.readInt32();
		for (i in 0...count) {
			var key = bytesInput.readInt32();
			var len = bytesInput.readInt32();
			var arr = [];
			for (j in 0...len)
				arr.push(bytesInput.readInt32());
			identMap.set(key, arr);
		}
	}
}

@:publicFields
class Compiler {
	var breakLineCount = 0;

	var inFunction:Bool = false;

	var dsoVersion = 33;

	var globalFloatTable:Array<Float> = [];
	var functionFloatTable:Array<Float> = [];

	var currentFloatTable:Array<Float>;

	var globalStringTable:StringTable = new StringTable();
	var functionStringTable:StringTable = new StringTable();

	var currentStringTable:StringTable;

	var identTable:IdentTable;

	public function new() {
		currentFloatTable = globalFloatTable;
		currentStringTable = globalStringTable;
		identTable = new IdentTable();
	}

	public function precompileIdent(ident:String) {
		if (ident != null)
			globalStringTable.add(ident, false, false);
	}

	public function compileIdent(ident:String, ip:Int) {
		if (ident != null)
			identTable.add(this, ident, ip);
		return 0;
	}

	public function addIntString(value:Int):Int {
		return currentStringTable.add('${value}', true, false);
	}

	public function addFloatString(value:Float):Int {
		return currentStringTable.add('${value}', true, false);
	}

	public function addFloat(value:Float):Int {
		if (currentFloatTable.contains(value))
			return currentFloatTable.indexOf(value);
		else {
			currentFloatTable.push(value);
			return currentFloatTable.length - 1;
		}
	}

	public function addString(value:String, caseSens:Bool, tag:Bool):Int {
		return currentStringTable.add(value, caseSens, tag);
	}

	public function stringToNumber(value:String):Float {
		if (value == "true")
			return 1;
		if (value == "false")
			return 0;

		var val = Std.parseFloat(value);

		if (Math.isNaN(val)) {
			return 0;
		}

		return val;
	}

	public function setTable(target:ConstTable, prop:ConstTableType) {
		switch (target) {
			case FloatTable:
				switch (prop) {
					case Global:
						currentFloatTable = globalFloatTable;
					case Function:
						currentFloatTable = functionFloatTable;
				}

			case StringTable:
				switch (prop) {
					case Global:
						currentStringTable = globalStringTable;
					case Function:
						currentStringTable = functionStringTable;
				}
		}
	}

	public function compile(code:String) {
		var statementList:Array<Stmt> = null;
		// try {
		var scanner = new Scanner(code);
		var toks = scanner.scanTokens();
		var parser = new Parser(toks);
		statementList = parser.parse();
		// } catch (e) {
		// 	trace(e.message);
		// 	return null;
		// }

		var outData = new BytesBuffer();
		outData.addInt32(dsoVersion);

		globalFloatTable = [];
		globalStringTable = new StringTable();
		functionFloatTable = [];
		functionStringTable = new StringTable();
		identTable = new IdentTable();
		currentStringTable = globalStringTable;
		currentFloatTable = globalFloatTable;

		this.inFunction = false;
		breakLineCount = 0;

		var codeSize = 1;

		if (statementList.length != 0) {
			codeSize = Stmt.precompileBlock(this, statementList, 0) + 1;
		}

		var lineBreakPairCount = breakLineCount;
		var context = new CompileContext(codeSize, lineBreakPairCount);
		context.breakPoint = 0;
		context.continuePoint = 0;
		context.ip = 0;

		globalStringTable.write(outData);
		outData.addInt32(globalFloatTable.length);
		for (f in globalFloatTable) {
			outData.addDouble(f);
		}
		functionStringTable.write(outData);
		outData.addInt32(functionFloatTable.length);
		for (f in functionFloatTable) {
			outData.addDouble(f);
		}

		breakLineCount = 0;
		var lastIp = 0;
		if (statementList.length != 0) {
			lastIp = Stmt.compileBlock(this, context, statementList);
		}

		if (lastIp != codeSize - 1)
			throw new Exception("Precompile size mismatch");

		context.codeStream[lastIp++] = cast OpCode.Return;
		var totSize = codeSize + breakLineCount * 2;
		outData.addInt32(codeSize);
		outData.addInt32(lineBreakPairCount);

		for (i in 0...codeSize) {
			if (context.codeStream[i] < 0xFF)
				outData.addByte(context.codeStream[i]);
			else {
				outData.addByte(0xFF);
				outData.addInt32(context.codeStream[i]);
			}
		}
		for (ibyte in context.lineBreakPairs) {
			outData.addInt32(ibyte);
		}

		identTable.write(outData);

		return outData;
	}
}

@:publicFields
class CompileContext {
	var codeStream:Vector<Int>;

	var lineBreakPairs:Vector<Int>;

	var ip:Int;
	var continuePoint:Int;
	var breakPoint:Int;

	var codeSize:Int;
	var lineBreakPairSize:Int;

	public function new(codeSize:Int, lineBreakPairSize:Int) {
		codeStream = new Vector<Int>(codeSize);
		lineBreakPairs = new Vector<Int>(lineBreakPairSize);

		this.codeSize = codeSize;
		this.lineBreakPairSize = lineBreakPairSize;
	}
}
