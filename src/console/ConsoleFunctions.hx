package console;

import haxe.io.Path;
import haxe.io.BytesInput;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

@:build(console.ConsoleFunctionMacro.build())
class ConsoleFunctions {
	// Sim Functions
	@:consoleFunction(usage = "nameToID(object)", minArgs = 2, maxArgs = 2)
	static function nameToId(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		var obj = vm.findObject(args[1]);
		if (obj != null) {
			return obj.id;
		}
		return -1;
	}

	@:consoleFunction(usage = "isObject(object)", minArgs = 2, maxArgs = 2)
	static function isObject(vm:VM, thisObj:SimObject, args:Array<String>):Bool {
		if (args[1] == "" || args[1] == "0") {
			return false;
		}
		var obj = vm.findObject(args[1]);
		if (obj != null) {
			return true;
		}
		return false;
	}

	@:consoleFunction(usage = "cancel(eventId)", minArgs = 2, maxArgs = 2)
	static function cancelEvent(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		vm.cancelEvent(Std.parseInt(args[1]));
	}

	@:consoleFunction(usage = "isEventPending(eventId)", minArgs = 2, maxArgs = 2)
	static function isEventPending(vm:VM, thisObj:SimObject, args:Array<String>):Bool {
		return vm.isEventPending(Std.parseInt(args[1]));
	}

	@:consoleFunction(usage = "schedule(time, refobject|0, command, <arg1...argN)", minArgs = 4, maxArgs = 0)
	static function schedule(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		var timeDelta = Std.parseInt(args[1]);
		var obj = vm.findObject(args[2]);
		if (obj == null) {
			if (args[2] != '0')
				return 0;
		}
		return vm.schedule(timeDelta, obj, args.slice(3));
	}

	@:consoleFunction(usage = "getSimTime()", minArgs = 1, maxArgs = 1)
	static function getSimTime(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		#if js
		return (js.lib.Date.now() - vm.startTime);
		#end
		#if sys
		return (Sys.time() - vm.startTime) * 1000;
		#end
	}

	@:consoleFunction(usage = "getRealTime()", minArgs = 1, maxArgs = 1)
	static function getRealTime(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		#if js
		return js.lib.Date.now();
		#end
		#if sys
		return (Sys.time() * 1000);
		#end
	}

	// String functions
	#if sys
	@:consoleFunction(usage = "expandFilename(filename)", minArgs = 2, maxArgs = 2)
	static function expandFilename(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var path = args[1];
		if (path.charAt(0) == "~")
			path = "." + path.substr(1);

		return FileSystem.absolutePath(path);
	}
	#end

	@:consoleFunction(usage = "strcmp(string one, string two)", minArgs = 3, maxArgs = 3)
	static function strcmp(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		var a = args[1];
		var b = args[2];
		if (a.length > b.length)
			return 1;
		else if (a.length < b.length)
			return -1;
		else {
			for (c in 0...a.length) {
				if (a.charCodeAt(c) > b.charCodeAt(c))
					return 1;
				else if (a.charCodeAt(c) < b.charCodeAt(c))
					return -1;
			}
			return 0;
		}
	}

	@:consoleFunction(usage = "stricmp(string one, string two)", minArgs = 3, maxArgs = 3)
	static function stricmp(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		var a = args[1].toUpperCase();
		var b = args[2].toUpperCase();
		if (a.length > b.length)
			return 1;
		else if (a.length < b.length)
			return -1;
		else {
			for (c in 0...a.length) {
				if (a.charCodeAt(c) > b.charCodeAt(c))
					return 1;
				else if (a.charCodeAt(c) < b.charCodeAt(c))
					return -1;
			}
			return 0;
		}
	}

	@:consoleFunction(usage = "strlen(string)", minArgs = 2, maxArgs = 2)
	static function strlen(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		return args[1].length;
	}

	@:consoleFunction(usage = "strstr(string one, string two)", minArgs = 3, maxArgs = 3)
	static function strstr(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		var a = args[1];
		var b = args[2];
		return a.indexOf(b);
	}

	@:consoleFunction(usage = "strpos(string hay, string needle, int offset)", minArgs = 3, maxArgs = 4)
	static function strpos(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		var a = args[1];
		var b = args[2];
		var c = args.length == 4 ? Std.parseInt(args[3]) : 0;
		return a.indexOf(b, c);
	}

	@:consoleFunction(usage = "ltrim(string value)", minArgs = 2, maxArgs = 2)
	static function ltrim(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return StringTools.ltrim(args[1]);
	}

	@:consoleFunction(usage = "rtrim(string value)", minArgs = 2, maxArgs = 2)
	static function rtrim(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return StringTools.rtrim(args[1]);
	}

	@:consoleFunction(usage = "trim(string value)", minArgs = 2, maxArgs = 2)
	static function trim(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return StringTools.trim(args[1]);
	}

	@:consoleFunction(usage = "stripChars(string value, string chars)", minArgs = 3, maxArgs = 3)
	static function stripChars(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var str = args[1];
		for (c in 0...args[2].length) {
			str = StringTools.replace(str, args[2].charAt(c), "");
		}
		return str;
	}

	@:consoleFunction(usage = "strlwr(string value)", minArgs = 2, maxArgs = 2)
	static function strlwr(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return args[1].toLowerCase();
	}

	@:consoleFunction(usage = "strupr(string value)", minArgs = 2, maxArgs = 2)
	static function strupr(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return args[1].toUpperCase();
	}

	@:consoleFunction(usage = "strchr(string value, string char)", minArgs = 3, maxArgs = 3)
	static function strchr(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var index = args[1].indexOf(args[2]);
		if (index == -1)
			return "";
		return args[1].substr(index);
	}

	@:consoleFunction(usage = "strreplace(string source, string from, string to)", minArgs = 4, maxArgs = 4)
	static function strreplace(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return StringTools.replace(args[1], args[2], args[3]);
	}

	@:consoleFunction(usage = "getSubStr(string str, int start, int numChars)", minArgs = 4, maxArgs = 4)
	static function getSubStr(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var s = args[1].substr(Std.parseInt(args[2]), Std.parseInt(args[3]));
		return s != null ? s : "";
	}

	// Field manipulators

	@:consoleFunction(usage = "getWord(string str, int index)", minArgs = 3, maxArgs = 3)
	static function getWord(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split(" ");
		var index = Std.parseInt(args[2]);
		if (index >= toks.length || index < 0)
			return "";
		return toks[index];
	}

	@:consoleFunction(usage = "getWords(string str, int index, int endIndex = INF)", minArgs = 3, maxArgs = 4)
	static function getWords(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split(" ");
		var index = Std.parseInt(args[2]);
		var endIndex = args.length == 4 ? Std.parseInt(args[3]) : toks.length;
		if (index >= toks.length || index < 0)
			return "";
		if (endIndex >= toks.length || endIndex < 0)
			return "";
		return toks.slice(index, endIndex).join(" ");
	}

	@:consoleFunction(usage = "setWord(text, index, replace)", minArgs = 4, maxArgs = 4)
	static function setWord(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split(" ");
		var index = Std.parseInt(args[2]);
		if (index >= toks.length || index < 0)
			return args[1];
		toks[index] = args[3];
		return toks.join(" ");
	}

	@:consoleFunction(usage = "removeWord(text, index)", minArgs = 3, maxArgs = 3)
	static function removeWord(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split(" ");
		var index = Std.parseInt(args[2]);
		if (index >= toks.length || index < 0)
			return args[1];
		toks.splice(index, 1);
		return toks.join(" ");
	}

	@:consoleFunction(usage = "getWordCount(string str)", minArgs = 2, maxArgs = 2)
	static function getWordCount(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		return args[1].split(" ").length;
	}

	@:consoleFunction(usage = "getField(string str, int index)", minArgs = 3, maxArgs = 3)
	static function getField(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split("\t");
		var index = Std.parseInt(args[2]);
		if (index >= toks.length || index < 0)
			return "";
		return toks[index];
	}

	@:consoleFunction(usage = "getFields(string str, int index, int endIndex = INF)", minArgs = 3, maxArgs = 4)
	static function getFields(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split("\t");
		var index = Std.parseInt(args[2]);
		var endIndex = args.length == 4 ? Std.parseInt(args[3]) : toks.length;
		if (index >= toks.length || index < 0)
			return "";
		if (endIndex >= toks.length || endIndex < 0)
			return "";
		return toks.slice(index, endIndex).join("\t");
	}

	@:consoleFunction(usage = "setField(text, index, replace)", minArgs = 4, maxArgs = 4)
	static function setField(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split("\t");
		var index = Std.parseInt(args[2]);
		if (index >= toks.length || index < 0)
			return args[1];
		toks[index] = args[3];
		return toks.join("\t");
	}

	@:consoleFunction(usage = "removeField(text, index)", minArgs = 3, maxArgs = 3)
	static function removeField(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split("\t");
		var index = Std.parseInt(args[2]);
		if (index >= toks.length || index < 0)
			return args[1];
		toks.splice(index, 1);
		return toks.join("\t");
	}

	@:consoleFunction(usage = "getFieldCount(string str)", minArgs = 2, maxArgs = 2)
	static function getFieldCount(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		return args[1].split("\t").length;
	}

	@:consoleFunction(usage = "getRecord(string str, int index)", minArgs = 3, maxArgs = 3)
	static function getRecord(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split("\n");
		var index = Std.parseInt(args[2]);
		if (index >= toks.length || index < 0)
			return "";
		return toks[index];
	}

	@:consoleFunction(usage = "getRecords(string str, int index, int endIndex = INF)", minArgs = 3, maxArgs = 4)
	static function getRecords(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split("\n");
		var index = Std.parseInt(args[2]);
		var endIndex = args.length == 4 ? Std.parseInt(args[3]) : toks.length;
		if (index >= toks.length || index < 0)
			return "";
		if (endIndex >= toks.length || endIndex < 0)
			return "";
		return toks.slice(index, endIndex).join("\n");
	}

	@:consoleFunction(usage = "setRecord(text, index, replace)", minArgs = 4, maxArgs = 4)
	static function setRecord(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split("\n");
		var index = Std.parseInt(args[2]);
		if (index >= toks.length || index < 0)
			return args[1];
		toks[index] = args[3];
		return toks.join("\n");
	}

	@:consoleFunction(usage = "removeRecord(text, index)", minArgs = 3, maxArgs = 3)
	static function removeRecord(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split("\n");
		var index = Std.parseInt(args[2]);
		if (index >= toks.length || index < 0)
			return args[1];
		toks.splice(index, 1);
		return toks.join("\n");
	}

	@:consoleFunction(usage = "getRecordCount(string str)", minArgs = 2, maxArgs = 2)
	static function getRecordCount(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		return args[1].split("\n").length;
	}

	@:consoleFunction(usage = "firstWord(string str)", minArgs = 2, maxArgs = 2)
	static function firstWord(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split(" ");
		if (toks.length == 0)
			return "";
		return toks[0];
	}

	@:consoleFunction(usage = "restWords(string str)", minArgs = 2, maxArgs = 2)
	static function restWords(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split(" ");
		if (toks.length == 0)
			return "";
		return toks.slice(1).join(" ");
	}

	@:consoleFunction(usage = "nextToken(str, token, delim)", minArgs = 4, maxArgs = 4)
	static function nextToken(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var toks = args[1].split(args[3]);
		if (toks.length == 0)
			return "";
		var rest = toks.slice(1).join(args[3]);
		if (vm.evalState.stack.length != 0) {
			var v = new VM.Variable("%" + args[2], vm);
			v.setStringValue(toks[0]);
			vm.evalState.stackVars[vm.evalState.stackVars.length - 1].set("%" + args[2], v);
		} else {
			var v = new VM.Variable("$" + args[2], vm);
			v.setStringValue(toks[0]);
			vm.evalState.globalVars.set("$" + args[2], v);
		}
		return rest;
	}

	// Tagged strings

	@:consoleFunction(usage = "detag(textTagString)", minArgs = 2, maxArgs = 2)
	static function detag(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var ccode = args[1].charCodeAt(0);
		if (ccode == null)
			return args[1];
		if (ccode == 1) {
			var findIdx = args[1].indexOf(' ');
			if (findIdx == -1)
				return "";
			var word = args[1].substr(findIdx);
			return word;
		}
		return args[1];
	}

	@:consoleFunction(usage = "getTag(textTagString)", minArgs = 2, maxArgs = 2)
	static function getTag(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var ccode = args[1].charCodeAt(0);
		if (ccode == null)
			return "";
		if (ccode == 1) {
			var findIdx = args[1].indexOf(' ');
			if (findIdx == -1)
				return args[1].substr(1);
			var word = args[1].substr(1, findIdx);
			return word;
		}
		return "";
	}

	// Package functions

	@:consoleFunction(usage = "activatePackage(package)", minArgs = 2, maxArgs = 2)
	static function activatePackage(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		vm.activatePackage(args[1]);
	}

	@:consoleFunction(usage = "deactivatePackage(package)", minArgs = 2, maxArgs = 2)
	static function deactivatePackage(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		vm.deactivatePackage(args[1]);
	}

	@:consoleFunction(usage = "isPackage(package)", minArgs = 2, maxArgs = 2)
	static function isPackage(vm:VM, thisObj:SimObject, args:Array<String>):Bool {
		for (nm in vm.namespaces) {
			if (nm.pkg == args[1])
				return true;
		}
		return false;
	}

	// Output

	@:consoleFunction(usage = "echo(value, ...)", minArgs = 2, maxArgs = 0)
	static function echo(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		Log.println(args.slice(1).join(""));
	}

	@:consoleFunction(usage = "warn(value, ...)", minArgs = 2, maxArgs = 0)
	static function warn(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		Log.println("Warning: " + args.slice(1).join(""));
	}

	@:consoleFunction(usage = "error(value, ...)", minArgs = 2, maxArgs = 0)
	static function error(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		Log.println("Error: " + args.slice(1).join(""));
	}

	@:consoleFunction(usage = "expandEscape(text)", minArgs = 2, maxArgs = 2)
	static function expandEscape(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return Scanner.escape(args[1]);
	}

	@:consoleFunction(usage = "collapseEscape(text)", minArgs = 2, maxArgs = 2)
	static function collapseEscape(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return Scanner.unescape(args[1]);
	}

	#if sys
	@:consoleFunction(usage = "quit()", minArgs = 1, maxArgs = 1)
	static function quit(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		Sys.exit(0);
	}

	// Metascripting

	@:consoleFunction(usage = "compile(fileName)", minArgs = 2, maxArgs = 2)
	static function compile(vm:VM, thisObj:SimObject, args:Array<String>):Bool {
		var f = args[1];
		if (!FileSystem.exists(f)) {
			Log.println('exec: invalid script file ${f}');
			return false;
		}
		var compiler = new Compiler();
		Log.println('Compiling ${f}...');
		var dso = compiler.compile(File.getContent(f));
		File.saveBytes(f + '.dso', dso.getBytes());
		return true;
	}

	@:consoleFunction(usage = "exec(fileName)", minArgs = 2, maxArgs = 2)
	static function exec(vm:VM, thisObj:SimObject, args:Array<String>):Bool {
		var f = args[1];
		if (!FileSystem.exists(f) && !FileSystem.exists(f + '.dso')) {
			Log.println('exec: invalid script file ${f}');
			return false;
		}
		if (FileSystem.exists(f)) {
			var compiler = new Compiler();
			Log.println('Compiling ${f}...');
			var dso = compiler.compile(File.getContent(f));
			File.saveBytes(f + '.dso', dso.getBytes());
		}

		if (FileSystem.exists(f + '.dso')) {
			Log.println('Loading compiled script ${f}.');
			vm.exec(f);
		}

		return true;
	}
	#end

	@:consoleFunction(usage = "eval(consoleString)", minArgs = 2, maxArgs = 2)
	static function eval(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var compiler = new Compiler();
		try {
			var bytes = compiler.compile(args[1]);
			var code = new CodeBlock(vm, null);
			code.load(new BytesInput(bytes.getBytes()));
			return code.exec(0, null, null, [], false, null);
		} catch (e) {
			Log.println("Syntax error in input");
			return "";
		}
	}

	#if js
	@:consoleFunction(usage = "eval_js(consoleString)", minArgs = 2, maxArgs = 2)
	static function eval_js(vm:VM, thisObj:SimObject, args:Array<String>):String {
		try {
			var scanner = new Scanner(args[1]);
			var parser = new Parser(scanner.scanTokens());
			var stmts = parser.parse();
			var jsgen = new JSGenerator(stmts);
			var jsOut = jsgen.generate(false);
			return '${js.Lib.eval(jsOut)}';
		} catch (e) {
			Log.println("Syntax error in input");
			return "";
		}
	}
	#end

	@:consoleFunction(name = "trace", usage = "trace(bool)", minArgs = 2, maxArgs = 2)
	static function trace_function(vm:VM, thisObj:SimObject, args:Array<String>):Void {
		vm.traceOn = Std.parseInt(args[1]) > 0;
		Log.println('Console trace is ${vm.traceOn ? "on" : "off"}.');
	}

	// FileSystem
	#if sys
	static var findFiles:Array<String> = null;

	static var findFilesIndex:Int = 0;

	static function walk(path:String, relPath:String) {
		var files = FileSystem.readDirectory(path);
		for (file in files) {
			if (FileSystem.isDirectory(path + '/' + file))
				walk(path + '/' + file, (relPath != "" ? relPath + '/' : "") + file);
			else
				findFiles.push((relPath != "" ? relPath + '/' : "") + file);
		}
	}

	static function isMatch(str:String, rgx:String) {
		var i = 0;
		var j = 0;
		while (i < str.length) {
			var ch = str.charAt(i).toUpperCase();
			var rg = rgx.charAt(j).toUpperCase();
			if (rg == "" && ch != "") // Regex was smaller than file name
				return false;
			if (ch == "" && rg != "") // Filename was smaller than regex
				return false;
			if (rg == "*") {
				var endRg = rgx.charAt(j + 1).toUpperCase();
				while (ch != endRg) {
					i++;
					ch = str.charAt(i).toUpperCase();
					if (ch == "" && endRg == "")
						return true;
					if (ch == "" && endRg != "")
						return false;
				}
				j++;
			} else if (rg == "?") {
				// Literally do nothing
			} else if (ch != rg) {
				return false;
			}
			i++;
			j++;
		}
		return true;
	}

	@:consoleFunction(usage = "findFirstFile(string pattern)", minArgs = 2, maxArgs = 2)
	static function findFirstFile(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var path = args[1];
		if (path.charAt(0) == "~")
			path = "." + path.substr(1);

		var absPath = FileSystem.absolutePath(path);
		var dir = Path.directory(absPath);
		findFiles = [];
		findFilesIndex = 0;
		walk(dir, Path.directory(path));
		var rgx = Path.withoutDirectory(args[1]);
		for (i in findFilesIndex...findFiles.length) {
			if (isMatch(findFiles[i], rgx)) {
				findFilesIndex = i + 1;
				return findFiles[i];
			}
		}
		return "";
	}

	@:consoleFunction(usage = "findNextFile(string pattern)", minArgs = 2, maxArgs = 2)
	static function findNextFile(vm:VM, thisObj:SimObject, args:Array<String>):String {
		if (findFiles == null) {
			return findFirstFile(vm, thisObj, args);
		}

		var path = args[1];
		if (path.charAt(0) == "~")
			path = "." + path.substr(1);

		var rgx = Path.withoutDirectory(args[1]);
		for (i in findFilesIndex...findFiles.length) {
			if (isMatch(findFiles[i], rgx)) {
				findFilesIndex = i + 1;
				return findFiles[i];
			}
		}
		return "";
	}

	@:consoleFunction(usage = "getFileCount(string pattern)", minArgs = 2, maxArgs = 2)
	static function getFileCount(vm:VM, thisObj:SimObject, args:Array<String>):Int {
		var path = args[1];
		if (path.charAt(0) == "~")
			path = "." + path.substr(1);

		var absPath = FileSystem.absolutePath(path);
		var dir = Path.directory(absPath);
		findFiles = [];
		findFilesIndex = 0;
		walk(dir, Path.directory(path));
		var rgx = Path.withoutDirectory(args[1]);
		var count = 0;
		for (i in findFilesIndex...findFiles.length) {
			if (isMatch(findFiles[i], rgx)) {
				findFilesIndex = i + 1;
				count++;
			}
		}
		return count;
	}

	@:consoleFunction(usage = "isFile(fileName)", minArgs = 2, maxArgs = 2)
	static function isFile(vm:VM, thisObj:SimObject, args:Array<String>):Bool {
		return FileSystem.exists(args[1]);
	}
	#end

	@:consoleFunction(usage = "fileExt(fileName)", minArgs = 2, maxArgs = 2)
	static function fileExt(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return Path.extension(args[1]);
	}

	@:consoleFunction(usage = "fileBase(fileName)", minArgs = 2, maxArgs = 2)
	static function fileBase(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return Path.withoutExtension(Path.withoutDirectory(args[1]));
	}

	@:consoleFunction(usage = "fileName(fileName)", minArgs = 2, maxArgs = 2)
	static function fileName(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return Path.withoutDirectory(args[1]);
	}

	@:consoleFunction(usage = "filePath(fileName)", minArgs = 2, maxArgs = 2)
	static function filePath(vm:VM, thisObj:SimObject, args:Array<String>):String {
		return Path.directory(args[1]);
	}
}
