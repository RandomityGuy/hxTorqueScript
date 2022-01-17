package;

import haxe.EnumTools;
import expr.OpCode;
import haxe.display.Display.Package;
import haxe.Exception;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.BytesBuffer;

using haxe.EnumTools;

enum LineType {
	GlobalStringTable;
	GlobalFloatTable;
	FunctionStringTable;
	FunctionFloatTable;
	IdentTable;
	Code;
}

enum DisassemblyVerbosity {
	Code;
	Args;
	ConstTables;
	ConstTableReferences;
}

abstract class DissassemblyData {}

@:publicFields
class DisassemblyReference extends DissassemblyData {
	var referencesWhat:LineType;
	var referenceIndex:Int;

	public function new(referencesWhat:LineType, referenceIndex:Int) {
		this.referencesWhat = referencesWhat;
		this.referenceIndex = referenceIndex;
	}
}

class DisassemblyConst<T> extends DissassemblyData {
	public var value:T;

	public function new(value:T) {
		this.value = value;
	}
}

typedef DisassmblyLine = {
	var type:LineType;
	var opCode:OpCode;
	var args:Array<DissassemblyData>;
	var lineNo:Int;
};

@:publicFields
class Disassembler {
	var globalFloatTable:Array<Float> = [];
	var functionFloatTable:Array<Float> = [];
	var globalStringTable:String;
	var functionStringTable:String;
	var identTable:Compiler.IdentTable = new Compiler.IdentTable();
	var dsoVersion = 33;
	var codeStream:Array<Int> = [];
	var lineBreakPairs:Array<Int> = [];

	var inFunction:Bool = false;

	var identMap:Map<Int, String> = [0 => null];
	var identMapSize = 1;

	var opCodeLookup:Map<Int, String> = [];

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

	function getStringTableValueFromRef(table:String, ref:Int) {
		var zeroCount = 0;
		var str = new StringBuf();
		for (i in 0...table.length) {
			if (table.charCodeAt(i) == 0) {
				if (zeroCount == ref)
					return str.toString();
				str = new StringBuf();
				zeroCount++;
			} else {
				str.add(table.charAt(i));
			}
		}
		return "";
	}

	function normalizeSTE(steType:LineType, index:Int) {
		var zeroCount = 0;
		if (steType == GlobalStringTable) {
			for (i in 0...globalStringTable.length) {
				if (globalStringTable.charCodeAt(i) == 0)
					zeroCount++;
				if (i == index)
					return zeroCount;
			}
		}
		if (steType == FunctionStringTable) {
			for (i in 0...functionStringTable.length) {
				if (functionStringTable.charCodeAt(i) == 0)
					zeroCount++;
				if (i == index)
					return zeroCount;
			}
		}

		return -1;
	}

	public function disassembleCode() {
		var ip = 0;

		var lines = [];

		var endFuncIp = -1;

		while (true) {
			if (ip == codeStream.length)
				break;

			if (ip == endFuncIp)
				this.inFunction = false;

			var instruction:OpCode = cast codeStream[ip++];

			switch (instruction) {
				case FuncDecl:
					var fnName = new DisassemblyReference(LineType.IdentTable, codeStream[ip]);
					var fnNamespace = new DisassemblyReference(LineType.IdentTable, codeStream[ip + 1]);
					var fnPackage = new DisassemblyReference(LineType.IdentTable, codeStream[ip + 2]);
					var hasBody = new DisassemblyConst(codeStream[ip + 3]);
					var fnEndOffset = new DisassemblyReference(LineType.Code, codeStream[ip + 4]);
					endFuncIp = codeStream[ip + 4];
					var fnArgc = new DisassemblyConst(codeStream[ip + 5]);
					var fnArgs:Array<DissassemblyData> = [];
					for (i in 0...fnArgc.value) {
						fnArgs.push(new DisassemblyReference(LineType.IdentTable, codeStream[ip + 6 + i]));
					}
					this.inFunction = true;
					var line:DisassmblyLine = {
						type: Code,
						opCode: FuncDecl,
						args: [fnName, fnNamespace, fnPackage, hasBody, fnEndOffset, fnArgc].concat(fnArgs),
						lineNo: ip
					}
					ip += 6 + fnArgc.value;
					lines.push(line);

				case CreateObject:
					var objParent = new DisassemblyReference(LineType.IdentTable, codeStream[ip]);
					var datablock = new DisassemblyConst(codeStream[ip + 1]);
					var failJump = new DisassemblyReference(LineType.Code, codeStream[ip + 2]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: CreateObject,
						args: [objParent, datablock, failJump],
						lineNo: ip
					}
					ip += 3;
					lines.push(line);

				case CreateDataBlock | NameObject:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);

				case AddObject | EndObject:
					var root = new DisassemblyConst(codeStream[ip]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [root],
						lineNo: ip
					}
					ip++;
					lines.push(line);

				case JmpIffNot | JmpIfNot | JmpIff | JmpIf | JmpIfNotNP | JmpIfNP | Jmp:
					var jump = new DisassemblyReference(LineType.Code, codeStream[ip]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [jump],
						lineNo: ip
					}
					ip++;
					lines.push(line);

				case Return:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);

				case CmpEQ | CmpGT | CmpGE | CmpLT | CmpLE | CmpNE | Xor | Mod | BitAnd | BitOr | Not | NotF | OnesComplement | Shr | Shl | And | Or | Add |
					Sub | Mul | Div | Neg:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);

				case SetCurVar | SetCurVarCreate:
					var varIdx = new DisassemblyReference(LineType.IdentTable, codeStream[ip]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [varIdx],
						lineNo: ip
					}
					ip++;
					lines.push(line);

				case SetCurVarArray | SetCurVarArrayCreate:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);

				case LoadVarUInt | LoadVarFlt | LoadVarStr | SaveVarUInt | SaveVarFlt | SaveVarStr | SetCurObjectNew | SetCurObject:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);

				case SetCurField:
					var fieldIdx = new DisassemblyReference(LineType.IdentTable, codeStream[ip]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [fieldIdx],
						lineNo: ip
					}
					ip++;
					lines.push(line);

				case SetCurFieldArray:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);

				case LoadFieldUInt | LoadFieldFlt | LoadFieldStr | SaveFieldUInt | SaveFieldFlt | SaveFieldStr:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);

				case StrToUInt | StrToFlt | StrToNone | FltToUInt | FltToStr | FltToNone | UIntToFlt | UIntToStr | UIntToNone:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);

				case LoadImmedUInt:
					var immed = new DisassemblyConst(codeStream[ip]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [immed],
						lineNo: ip
					}
					ip++;
					lines.push(line);

				case LoadImmedFlt:
					var immed = new DisassemblyReference(this.inFunction ? LineType.FunctionFloatTable : LineType.GlobalFloatTable, codeStream[ip]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [immed],
						lineNo: ip
					}
					ip++;
					lines.push(line);

				case TagToStr | LoadImmedStr:
					var ref = new DisassemblyReference(this.inFunction ? LineType.FunctionStringTable : LineType.GlobalStringTable,
						this.normalizeSTE(this.inFunction ? LineType.FunctionStringTable : LineType.GlobalStringTable, codeStream[ip]));
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [ref],
						lineNo: ip
					}
					ip++;
					lines.push(line);

				case LoadImmedIdent:
					var ref = new DisassemblyReference(LineType.IdentTable, codeStream[ip]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [ref],
						lineNo: ip
					}
					ip++;
					lines.push(line);

				case CallFunc | CallFuncResolve:
					var fnName = new DisassemblyReference(LineType.IdentTable, codeStream[ip]);
					var fnNamespace = new DisassemblyReference(LineType.IdentTable, codeStream[ip + 1]);
					var callType = new DisassemblyConst(codeStream[ip + 2]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [fnName, fnNamespace, callType],
						lineNo: ip
					}
					ip += 3;
					lines.push(line);

				case ProcessArgs | AdvanceStr | AdvanceStrComma | AdvanceStrNul | RewindStr | TerminateRewindStr | CompareStr:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);

				case AdvanceStrAppendChar:
					var char = new DisassemblyConst(codeStream[ip]);
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [char],
						lineNo: ip
					}
					ip++;
					lines.push(line);

				case Push | PushFrame | Break | Invalid:
					var line:DisassmblyLine = {
						type: Code,
						opCode: instruction,
						args: [],
						lineNo: ip
					}
					lines.push(line);
			}
		}

		var totalDism:Array<DisassmblyLine> = [];

		var zeroCount = 0;
		var str = new StringBuf();
		for (i in 0...globalStringTable.length) {
			if (globalStringTable.charCodeAt(i) == 0) {
				totalDism.push({
					type: LineType.GlobalStringTable,
					lineNo: zeroCount,
					opCode: cast 0,
					args: [new DisassemblyConst(str.toString())]
				});
				str = new StringBuf();
				zeroCount++;
			} else {
				str.add(globalStringTable.charAt(i));
			}
		}

		for (i in 0...globalFloatTable.length) {
			totalDism.push({
				type: LineType.GlobalFloatTable,
				lineNo: i,
				opCode: cast 0,
				args: [new DisassemblyConst(globalFloatTable[i])]
			});
		}

		var zeroCount = 0;
		var str = new StringBuf();
		for (i in 0...functionStringTable.length) {
			if (functionStringTable.charCodeAt(i) == 0) {
				totalDism.push({
					type: LineType.FunctionStringTable,
					lineNo: zeroCount,
					opCode: cast 0,
					args: [new DisassemblyConst(str.toString())]
				});
				str = new StringBuf();
				zeroCount++;
			} else {
				str.add(globalStringTable.charAt(i));
			}
		}

		for (i in 0...functionFloatTable.length) {
			totalDism.push({
				type: LineType.FunctionFloatTable,
				lineNo: i,
				opCode: cast 0,
				args: [new DisassemblyConst(functionFloatTable[i])]
			});
		}

		for (identIdx => ident in identMap) {
			totalDism.push({
				type: LineType.IdentTable,
				lineNo: identIdx,
				opCode: cast 0,
				args: [new DisassemblyConst(ident)]
			});
		}

		totalDism = totalDism.concat(lines);

		return totalDism;
	}

	public function writeDisassembly(lines:Array<DisassmblyLine>, outputVerbosity:haxe.EnumFlags<DisassemblyVerbosity>) {
		var output = new StringBuf();

		for (line in lines) {
			switch (line.type) {
				case GlobalStringTable:
					var strData:DisassemblyConst<String> = cast line.args[0];
					if (outputVerbosity.has(DisassemblyVerbosity.ConstTables))
						output.add("GlobalStringTable::" + StringTools.lpad('${line.lineNo}', "0", 5) + ": " + strData.value + "\n");

				case FunctionStringTable:
					var strData:DisassemblyConst<String> = cast line.args[0];
					if (outputVerbosity.has(DisassemblyVerbosity.ConstTables))
						output.add("FunctionStringTable::" + StringTools.lpad('${line.lineNo}', "0", 5) + ": " + strData.value + "\n");

				case GlobalFloatTable:
					var strData:DisassemblyConst<Float> = cast line.args[0];
					if (outputVerbosity.has(DisassemblyVerbosity.ConstTables))
						output.add("GlobalFloatTable::" + StringTools.lpad('${line.lineNo}', "0", 5) + ": " + strData.value + "\n");

				case FunctionFloatTable:
					var strData:DisassemblyConst<Float> = cast line.args[0];
					if (outputVerbosity.has(DisassemblyVerbosity.ConstTables))
						output.add("FunctionFloatTable::" + StringTools.lpad('${line.lineNo}', "0", 5) + ": " + strData.value + "\n");

				case IdentTable:
					var strData:DisassemblyConst<String> = cast line.args[0];
					if (outputVerbosity.has(DisassemblyVerbosity.ConstTables))
						output.add("IdentTable::" + StringTools.lpad('${line.lineNo}', "0", 5) + ": " + strData.value + "\n");

				case Code:
					var args = "";

					if (outputVerbosity.has(DisassemblyVerbosity.Args)) {
						for (arg in line.args) {
							if (Std.isOfType(arg, DisassemblyReference)) {
								var ref:DisassemblyReference = cast arg;
								var refStr = switch (ref.referencesWhat) {
									case GlobalStringTable:
										"GlobalStringTable::" + StringTools.lpad('${ref.referenceIndex}', "0",
											5) +
										(outputVerbosity.has(DisassemblyVerbosity.ConstTableReferences) ? '<-\"${this.getStringTableValueFromRef(this.globalStringTable, ref.referenceIndex)}"' : "");

									case FunctionStringTable:
										"FunctionStringTable::" + StringTools.lpad('${ref.referenceIndex}', "0",
											5) +
										(outputVerbosity.has(DisassemblyVerbosity.ConstTableReferences) ? '<-\"${this.getStringTableValueFromRef(this.functionStringTable, ref.referenceIndex)}"' : "");

									case GlobalFloatTable:
										"GlobalFloatTable::" + StringTools.lpad('${ref.referenceIndex}', "0",
											5) +
										(outputVerbosity.has(DisassemblyVerbosity.ConstTableReferences) ? '<-\"${this.globalFloatTable[ref.referenceIndex]}"' : "");

									case FunctionFloatTable:
										"FunctionFloatTable::" + StringTools.lpad('${ref.referenceIndex}', "0",
											5) +
										(outputVerbosity.has(DisassemblyVerbosity.ConstTableReferences) ? '<-\"${this.functionFloatTable[ref.referenceIndex]}"' : "");

									case IdentTable:
										"IdentTable::" + StringTools.lpad('${ref.referenceIndex}', "0",
											5) +
										(outputVerbosity.has(DisassemblyVerbosity.ConstTableReferences) ? '<-\"${this.identMap[ref.referenceIndex]}"' : "");

									case Code:
										"Code::" + StringTools.lpad('${ref.referenceIndex}', "0", 5);
								}

								args += refStr + " ";
							} else if (Std.isOfType(arg, DisassemblyConst)) {
								var c:DisassemblyConst<Int> = cast arg;
								args += '${c.value}' + " ";
							}
						}
					}

					output.add("Code::" + StringTools.lpad('${line.lineNo}', "0", 5) + ": " + opCodeLookup.get(cast line.opCode) + " " + args + "\n");
			}
		}

		return output.toString();
	}
}
