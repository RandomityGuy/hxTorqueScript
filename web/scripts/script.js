const runbutton = document.querySelector("#runbutton");
const consoleOutput = document.querySelector("#console-output");
const consoleInput = document.querySelector("#console-input");
const codeEditor = document.querySelector("#code-editor");
const clearConsole = document.querySelector("#clear-console");
const restartVM = document.querySelector("#restart-vm");
const runIcon = document.querySelector("#run-icon");
const runSpinner = document.querySelector("#run-spinner");
const disasmInput = document.querySelector("#disasm-input");
const disasmArgs = document.querySelector("#disasm-args");
const disasmConsts = document.querySelector("#disasm-consts");
const disasmRefs = document.querySelector("#disasm-refs");
const disasmOutput = document.querySelector("#disasm-output");
const transpileInput = document.querySelector("#transpile-input");
const transpilebutton = document.querySelector("#transpilebutton");
const transpileIcon = document.querySelector("#transpile-icon");
const transpileSpinner = document.querySelector("#transpile-spinner");
const transpileOutput = document.querySelector("#transpile-output");
const transpileDownload = document.querySelector("#transpile-download");
const transpileDownloadSmall = document.querySelector("#transpile-download-small");
const uploadCodeButton = document.querySelector("#uploadcodebutton");
const uploadTranspileButton = document.querySelector("#uploadtranspilebutton");

let editor = ace.edit("code-editor");
editor.session.setMode("ace/mode/torquescript");

let transpileEditor = ace.edit("transpile-input");
transpileEditor.session.setMode("ace/mode/torquescript");

let transpileOutputEditor = ace.edit("transpile-output");
transpileOutputEditor.session.setMode("ace/mode/javascript");
transpileOutputEditor.setReadOnly(true);

let tmpLine = "";
Log.setOutputFunction((txt, line) => {
    if (line) {
        consoleOutput.textContent += `${tmpLine + txt}\n`;
        tmpLine = "";
        consoleOutput.scrollTop = consoleOutput.scrollHeight - consoleOutput.clientHeight;
    } else {
        tmpLine += txt;
    }
});

let running = false;

let vm = new VM(true);

const uploadFunc = (ed) => {
    let input = document.createElement("input");
    input.type = "file";
    input.accept = ".cs";
    input.onchange = () => {
        let file = input.files[0];
        if (!file) {
            return;
        }
        let reader = new FileReader();
        reader.onload = () => {
            ed.setValue(reader.result);
            ed.clearSelection();
        };
        reader.readAsText(file);
    };
    input.click();
}

uploadCodeButton.addEventListener("click", () => {
    uploadFunc(editor);
})

uploadTranspileButton.addEventListener("click", () => {
    uploadFunc(transpileEditor);
})

runbutton.addEventListener("click", () => {
    if (running) return;
    running = true;
    runIcon.toggleAttribute("hidden");
    runSpinner.toggleAttribute("hidden");
    window.setTimeout(() => {
        try {
            let compiler = new Compiler();
            let bytes = compiler.compile(editor.getValue());
            let code = new CodeBlock(vm, null);
            code.loadFromData(bytes);
            code.exec(0, null, null, [], false, null);
        } catch (err) {
            Log.println("Syntax error in input.");
        }
        running = false;
        runIcon.toggleAttribute("hidden");
        runSpinner.toggleAttribute("hidden");
    }, 300);
})

clearConsole.addEventListener("click", () => {
    consoleOutput.textContent = "";
})

restartVM.addEventListener("click", () => {
    vm = new VM(true);
    Log.println("Restarting TorqueScript VM...");
})

codeEditor.onkeydown = (event) => {
    if (event.key == "Tab") {
        event.preventDefault();
        codeEditor.value += "    ";
    }
}

consoleInput.onkeydown = (event) => {
    if (event.key == "Enter") {
        event.preventDefault();
        Log.println("==> " + consoleInput.value);

        try {
            let compiler = new Compiler();
            let bytes = compiler.compile(consoleInput.value);
            let code = new CodeBlock(vm, null);
            code.loadFromData(bytes);
            code.exec(0, null, null, [], false, null);
        } catch (err) {
            Log.println("Syntax error in input.");
        }

        consoleInput.value = "";
    }
}

disasmInput.onchange = () => {
    let f = new FileReader();
    let file = disasmInput.files[0];
    f.readAsArrayBuffer(file);
    f.addEventListener('load', (ev) => {
        try {
            let ds = new Disassembler();
            ds.loadFromBytes(ev.target.result);
            let disasm = ds.disassembleCode();

            let va = disasmArgs.classList.contains("active");
            var vc = disasmConsts.classList.contains("active");
            var vr = disasmRefs.classList.contains("active");

            let verbosity = 0;
            verbosity |= va ? 1 << 1 : 0;
            verbosity |= vc ? 1 << 2 : 0;
            verbosity |= vr ? 1 << 3 : 0;

            let output = ds.writeDisassembly(disasm, verbosity);

            disasmOutput.textContent = output;
        } catch (err) {
            disasmOutput.textContent = "Cannot load disassembly";
        }
    })
}

let transpiling = false;
transpilebutton.addEventListener("click", () => {
    if (transpiling) return;
    transpiling = true;
    transpileIcon.toggleAttribute("hidden");
    transpileSpinner.toggleAttribute("hidden");
    window.setTimeout(() => {
        try {
            let scanner = new Scanner(transpileEditor.getValue());
            toks = scanner.scanTokens();
            parser = new Parser(toks);
            exprs = parser.parse();
            tsgen = new JSGenerator(exprs);
            let output = tsgen.generate(false);
            transpileOutputEditor.setValue(output);
            transpileOutputEditor.clearSelection();
        } catch (err) {
            transpileOutputEditor.setValue("// Syntax error in input.");
            transpileOutputEditor.clearSelection();
        }
        transpiling = false;
        transpileIcon.toggleAttribute("hidden");
        transpileSpinner.toggleAttribute("hidden");
    }, 300);
})

const downloadTranspilation = (withLib) => {
    try {
        let scanner = new Scanner(transpileEditor.getValue());
        toks = scanner.scanTokens();
        parser = new Parser(toks);
        exprs = parser.parse();
        tsgen = new JSGenerator(exprs);
        let output = tsgen.generate(withLib);

        let blob = new Blob([output], { type: "text/plain;charset=utf-8" });
        let url = URL.createObjectURL(blob);
        let a = document.createElement("a");
        a.href = url;
        a.download = "transpile.js";
        a.click();

    } catch (err) {
        transpileOutputEditor.setValue("// Syntax error in input.");
        transpileOutputEditor.clearSelection();
    }
}

transpileDownload.addEventListener("click", () => {
    downloadTranspilation(true);
})

transpileDownloadSmall.addEventListener("click", () => {
    downloadTranspilation(false);
})
