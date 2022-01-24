class TorqueVariable {
    constructor() {
        this.intValue = 0;
        this.floatValue = 0;
        this.stringValue = "";
        this.internalType = -1;
    }

    getIntValue() {
		if (this.internalType < -1) {
			return this.intValue;
		} else {
			if (__simObjects.has(this.stringValue.toLowerCase()))
				return __simObjects.get(this.stringValue.toLowerCase()).id;
			var intParse = parseInt(this.stringValue);
			if (intParse == null)
				return 0;
			else
				return intParse;
		}
    }
    
    getFloatValue() {
		if (this.internalType < -1) {
			return this.floatValue;
		} else {
			if (__simObjects.has(this.stringValue.toLowerCase()))
				return __simObjects.get(this.stringValue.toLowerCase()).id;
			var floatParse = parseFloat(this.stringValue);
			if (isNaN(floatParse))
				return 0;
			else
				return floatParse;
		}
    }
    
    getStringValue() {
		if (this.internalType == -1)
			return this.stringValue;
		if (this.internalType == -2)
			return String(this.floatValue);
		if (this.internalType == -3)
			return String(this.intValue);
		else
			return this.stringValue;
	}

	setIntValue(val) {
		if (this.internalType < -1) {
			this.intValue = val;
			this.floatValue = val;
			this.stringValue = null;
			this.internalType = -3;
		} else {
			this.intValue = val;
			this.floatValue = val
			this.stringValue = String(val);
		}
	}

	setFloatValue(val) {
		if (this.internalType < -1) {
			this.floatValue = val;
			this.intValue = Math.round(val);
			this.stringValue = null;
			this.internalType = -2;
		} else {
			this.floatValue = val;
			this.intValue = Math.round(this.floatValue);
			this.stringValue = String(val);
		}
	}

	setStringValue(val) {
		if (this.internalType < -1) {
			this.floatValue = parseFloat(val);
			this.intValue = Math.round(this.floatValue);
			this.internalType = -1;
			this.stringValue = val;
		} else {
			this.floatValue = parseFloat(val);
			this.intValue = Math.round(this.floatValue);
			this.stringValue = val;
		}
	}

	resolveArray(arrayIndex) {
		if (arrayIndex in this) {
			return this[arrayIndex];
		} else {
			let arrayObj = new TorqueVariable();
			this[arrayIndex] = arrayObj;
			return arrayObj;
		}
	}
}

const __namespaces = [
	{
		name: null,
		pkg: null,
		entries: [],
		parent: null
	}
];

const find_ns = (nsName) => {
	let nsList = __namespaces.filter(x => (x.name != null && nsName != null) ? (x.name.toLowerCase() == nsName.toLowerCase()) : x.name == nsName);
	if (nsList.length == 0)
		return null;
	return nsList[0];
}

const addConsoleFunction = (func, funcName, namespace, pkg) => {
	if (namespace == "")
		namespace = null;
	if (pkg == "")
		pkg = null;
	let nsList = __namespaces.filter(x => x.name != null ? (x.name.toLowerCase() == namespace.toLowerCase()) : x.name == namespace); 
	let ns = null;
	if (nsList.length == 0) {
		ns = {
			name: namespace,
			pkg: pkg,
			entries: [],
			parent: null
		};
		__namespaces.push(ns);
	} else {
		ns = nsList[0];
	}
	ns.entries.push({
		name: funcName,
		namespace: ns,
		pkg: pkg,
		func: func
	});
}

const ns_findfunc = (ns, funcName) => {
	for (let entry of ns.entries) {
		if (entry.name.toLowerCase() == funcName.toLowerCase()) {
			return entry;
		}
	}
	if (ns.parent != null)
		return ns_findfunc(ns.parent, funcName);
	return null;
}

const __idMap = new Map();
const __simObjects = new Map();
const __dataBlocks = new Map();
let nextObjectId = 2000;
let nextDataBlockId = 1;

class TorqueObject {
	constructor(className, name, isDatablock, parentName, props, children) {
		if (parentName != null) {
			let parentObj = __simObjects.get(parentName);
			if (parentObj != null) {
				Object.assign(this, parentObj);
			}
		}
		this.className = className;
		this.name = name;
		this.isDatablock = isDatablock;
		this.parentName = parentName;
		Object.assign(this, props);
		this.children = children;
		this.id = isDatablock ? nextDataBlockId : nextObjectId++;
		__idMap.set(this.id, this);
		if (!isDatablock)
			if (!__simObjects.has(this.name.toLowerCase()))
				__simObjects.set(this.name.toLowerCase(), this);
		if (isDatablock)
			__dataBlocks.set(this.id, this);
	}
}

const resolveIdent = (str) => {
	if (__simObjects.has(str.toLowerCase())) return __simObjects.get(str.toLowerCase());
	if (__dataBlocks.has(str.toLowerCase())) return __dataBlocks.get(str.toLowerCase());
}

let __currentNamespace = null;

const callFunc = (namespaceName, funcName, funcArgs, callType) => {
	let nsEntry = null;
	if (callType == "FunctionCall") {
		if (namespaceName == "")
			namespaceName = null;
		let ns = find_ns(namespaceName);
		if (ns != null) {
			nsEntry = ns_findfunc(ns, funcName);
		} else {
			console.warn("Cannot find namespace by name " + findObj.className);
			return;
		}
	} else if (callType == "MethodCall") {
		let objName = funcArgs[0];
		let findObj = __simObjects.get(objName.toLowerCase());
		if (findObj == null)
			findObj = __idMap.get(parseInt(objName));
		if (findObj == null) {
			console.error("Cannot find object or datablock by name '" + objName + "'");
			return;
		}
		let ns = find_ns(findObj.className);
		if (ns != null) {
			nsEntry = ns_findfunc(ns, funcName);
		} else {
			console.warn("Cannot find namespace by name " + findObj.className);
			return;
		}
	} else if (callType == "ParentCall") {
		if (__currentNamespace != null) {
			if (__currentNamespace.parent != null) {
				let ns = __currentNamespace.parent;
				nsEntry = ns_findfunc(ns, funcName);
			}
		}
	}
	if (nsEntry != null) {
		let fArgs = [];
		for (let val of funcArgs) {
			let tvar = new TorqueVariable();
			tvar.setStringValue(val);
			fArgs.push(tvar);
		}
		let saveNamespace = __currentNamespace;
		__currentNamespace = nsEntry.namespace;
		let res = nsEntry.func(fArgs);
		__currentNamespace = saveNamespace;
		return res;
	}
}

const __echo__ = (args) => {
	console.log(args[0].getStringValue());
}
addConsoleFunction(__echo__, "echo", "", "");