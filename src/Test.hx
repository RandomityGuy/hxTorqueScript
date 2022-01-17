import buddy.SingleSuite;
import haxe.io.BytesInput;
import sys.io.File;
import buddy.BuddySuite;
import buddy.SuitesRunner;
import haxe.io.Path;
import sys.FileSystem;

using buddy.Should;

class Test extends SingleSuite {
	public function new() {
		describe("TorqueScript VM Testing", {
			beforeAll({
				execDirectory("tests");
			});

			describe("array", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/array.cs.dso");
				});

				it("$result[1, 2, 3] should be int", {
					vm.evalState.globalVars.get("$result1_2_3").getIntValue().should.be(5);
				});

				it("$result[1, 2, 3] should be float", {
					vm.evalState.globalVars.get("$result1_2_3").getFloatValue().should.be(5);
				});

				it("$result[1, 2, 3] should be string", {
					vm.evalState.globalVars.get("$result1_2_3").getStringValue().should.be("5");
				});
			});

			describe("breakFor", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/breakFor.cs.dso");
				});

				it("$result::break should be int", {
					vm.evalState.globalVars.get("$result::break").getIntValue().should.be(15);
				});

				it("$result::break should be float", {
					vm.evalState.globalVars.get("$result::break").getFloatValue().should.be(15);
				});

				it("$result::break should be string", {
					vm.evalState.globalVars.get("$result::break").getStringValue().should.be("15");
				});
			});

			describe("breakWhile", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/breakWhile.cs.dso");
				});

				it("$result::break should be int", {
					vm.evalState.globalVars.get("$result::break").getIntValue().should.be(10);
				});

				it("$result::break should be float", {
					vm.evalState.globalVars.get("$result::break").getFloatValue().should.be(10);
				});

				it("$result::break should be string", {
					vm.evalState.globalVars.get("$result::break").getStringValue().should.be("10");
				});
			});

			describe("chaining", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/chaining.cs.dso");
				});

				it("$result::root", {
					vm.evalState.globalVars.get("$result::root").getIntValue().should.be(2000);
				});

				it("$result::a", {
					vm.evalState.globalVars.get("$result::a").getIntValue().should.be(2001);
				});

				it("$result::b", {
					vm.evalState.globalVars.get("$result::b").getIntValue().should.be(2002);
				});

				it("$result::c", {
					vm.evalState.globalVars.get("$result::c").getIntValue().should.be(2003);
				});
			});

			describe("chains", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/chains.cs.dso");
				});

				it("$result", {
					vm.evalState.globalVars.get("$result").getIntValue().should.be(2002);
				});
			});

			describe("combined", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/combined.cs.dso");
				});

				it("$result should be int", {
					vm.evalState.globalVars.get("$result").getIntValue().should.be(120);
				});

				it("$result should be float", {
					vm.evalState.globalVars.get("$result").getFloatValue().should.be(120);
				});

				it("$result should be string", {
					vm.evalState.globalVars.get("$result").getStringValue().should.be("120");
				});
			});

			describe("continueFor", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/continueFor.cs.dso");
				});

				it("$result::continue should be int", {
					vm.evalState.globalVars.get("$result::continue").getIntValue().should.be(10);
				});

				it("$result::continue should be float", {
					vm.evalState.globalVars.get("$result::continue").getFloatValue().should.be(10);
				});

				it("$result::continue should be string", {
					vm.evalState.globalVars.get("$result::continue").getStringValue().should.be("10");
				});
			});

			describe("continueWhile", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/continueWhile.cs.dso");
				});

				it("$result::continue should be int", {
					vm.evalState.globalVars.get("$result::continue").getIntValue().should.be(10);
				});

				it("$result::continue should be float", {
					vm.evalState.globalVars.get("$result::continue").getFloatValue().should.be(10);
				});

				it("$result::continue should be string", {
					vm.evalState.globalVars.get("$result::continue").getStringValue().should.be("10");
				});
			});

			describe("for", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/for.cs.dso");
				});

				it("$global should be int", {
					vm.evalState.globalVars.get("$global").getIntValue().should.be(50);
				});

				it("$global should be float", {
					vm.evalState.globalVars.get("$global").getFloatValue().should.be(50);
				});

				it("$global should be string", {
					vm.evalState.globalVars.get("$global").getStringValue().should.be("50");
				});
			});

			describe("function", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/function.cs.dso");
				});

				it("$result::normalFunction", {
					vm.evalState.globalVars.get("$result::normalFunction").getIntValue().should.be(7);
				});

				it("$result::boundFunction", {
					vm.evalState.globalVars.get("$result::boundFunction").getIntValue().should.be(2007);
				});
			});

			describe("if", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/if.cs.dso");
				});

				it("$one", {
					vm.evalState.globalVars.get("$one").getIntValue().should.be(10);
				});

				it("$two", {
					vm.evalState.globalVars.get("$two").getIntValue().should.be(-10);
				});

				it("$three", {
					vm.evalState.globalVars.get("$three").getIntValue().should.be(200);
				});

				it("$four", {
					vm.evalState.globalVars.get("$four").getIntValue().should.be(500);
				});
			});

			describe("memoryReference", {
				var vm:VM;

				beforeAll({
					vm = new VM();
					var pivar = new VM.Variable("$pi", vm);
					pivar.setFloatValue(3.14);
					vm.evalState.globalVars.set("$pi", pivar);
					vm.exec("tests/memoryReference.cs.dso");
				});

				it("$result", {
					vm.evalState.globalVars.get("$result").getFloatValue().should.be(6.28);
				});

				it("$pi", {
					vm.evalState.globalVars.get("$pi").getFloatValue().should.be(1337);
				});
			});

			describe("nestedBreakFor", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/nestedBreakFor.cs.dso");
				});

				it("$result::break should be int", {
					vm.evalState.globalVars.get("$result::break").getIntValue().should.be(6900);
				});

				it("$result::break should be float", {
					vm.evalState.globalVars.get("$result::break").getFloatValue().should.be(6900);
				});

				it("$result::break should be string", {
					vm.evalState.globalVars.get("$result::break").getStringValue().should.be("6900");
				});
			});

			describe("nestedBreakWhile", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/nestedBreakWhile.cs.dso");
				});

				it("$result::break should be int", {
					vm.evalState.globalVars.get("$result::break").getIntValue().should.be(6900);
				});

				it("$result::break should be float", {
					vm.evalState.globalVars.get("$result::break").getFloatValue().should.be(6900);
				});

				it("$result::break should be string", {
					vm.evalState.globalVars.get("$result::break").getStringValue().should.be("6900");
				});
			});

			describe("nestedContinueFor", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/nestedContinueFor.cs.dso");
				});

				it("$result::continue should be int", {
					vm.evalState.globalVars.get("$result::continue").getIntValue().should.be(5500);
				});

				it("$result::continue should be float", {
					vm.evalState.globalVars.get("$result::continue").getFloatValue().should.be(5500);
				});

				it("$result::continue should be string", {
					vm.evalState.globalVars.get("$result::continue").getStringValue().should.be("5500");
				});
			});

			describe("nestedContinueWhile", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/nestedContinueWhile.cs.dso");
				});

				it("$result::continue should be int", {
					vm.evalState.globalVars.get("$result::continue").getIntValue().should.be(5500);
				});

				it("$result::continue should be float", {
					vm.evalState.globalVars.get("$result::continue").getFloatValue().should.be(5500);
				});

				it("$result::continue should be string", {
					vm.evalState.globalVars.get("$result::continue").getStringValue().should.be("5500");
				});
			});

			describe("opOrder", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/opOrder.cs.dso");
				});

				it("$noParen", {
					vm.evalState.globalVars.get("$noParen").getIntValue().should.be(3);
				});

				it("$paren", {
					vm.evalState.globalVars.get("$paren").getIntValue().should.be(4);
				});
			});

			describe("package", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/package.cs.dso");
				});

				it("$before", {
					vm.evalState.globalVars.get("$before").getIntValue().should.be(1);
				});

				it("$afterA", {
					vm.evalState.globalVars.get("$afterA").getIntValue().should.be(2);
				});

				it("$afterB", {
					vm.evalState.globalVars.get("$afterB").getIntValue().should.be(3);
				});

				it("$beforeNamespace", {
					vm.evalState.globalVars.get("$beforeNamespace").getIntValue().should.be(2);
				});

				it("$afterANamespace", {
					vm.evalState.globalVars.get("$afterANamespace").getIntValue().should.be(4);
				});

				it("$afterBNamespace", {
					vm.evalState.globalVars.get("$afterBNamespace").getIntValue().should.be(6);
				});

				it("$afterADeactivated", {
					vm.evalState.globalVars.get("$afterADeactivated").getIntValue().should.be(2);
				});

				it("$afterADeactivatedNamespace", {
					vm.evalState.globalVars.get("$afterADeactivatedNamespace").getIntValue().should.be(4);
				});

				it("$afterBDeactivated", {
					vm.evalState.globalVars.get("$afterBDeactivated").getIntValue().should.be(1);
				});

				it("$afterBDeactivatedNamespace", {
					vm.evalState.globalVars.get("$afterBDeactivatedNamespace").getIntValue().should.be(2);
				});
			});

			describe("scriptObject", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/scriptObject.cs.dso");
				});

				it("$result", {
					vm.evalState.globalVars.get("$result").getIntValue().should.be(32);
				});
			});

			describe("simGroup", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/simGroup.cs.dso");
				});

				it("$result::Root1_0", {
					vm.evalState.globalVars.get("$result::Root1_0").getIntValue().should.be(0);
				});

				it("$result::Root2_0", {
					vm.evalState.globalVars.get("$result::Root2_0").getIntValue().should.be(0);
				});

				it("$result::Root1_1", {
					vm.evalState.globalVars.get("$result::Root1_1").getIntValue().should.be(1);
				});

				it("$result::Root2_1", {
					vm.evalState.globalVars.get("$result::Root2_1").getIntValue().should.be(0);
				});

				it("$result::Root1_2", {
					vm.evalState.globalVars.get("$result::Root1_2").getIntValue().should.be(0);
				});

				it("$result::Root2_2", {
					vm.evalState.globalVars.get("$result::Root2_2").getIntValue().should.be(1);
				});
			});

			describe("treeInitialization", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/treeInitialization.cs.dso");
				});

				it("$root::field", {
					vm.evalState.globalVars.get("$root::field").getStringValue().should.be("field");
				});

				it("$root::ChildRoot", {
					vm.evalState.globalVars.get("$root::ChildRoot").getStringValue().should.be("ChildRoot");
				});

				it("$root::childField", {
					vm.evalState.globalVars.get("$root::childField").getStringValue().should.be("childField");
				});

				it("$root::child", {
					vm.evalState.globalVars.get("$root::child").getStringValue().should.be("Child");
				});

				it("$root::childArray", {
					vm.evalState.globalVars.get("$root::childArray").getStringValue().should.be("childArrayField");
				});
			});

			describe("switch", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/switch.cs.dso");
				});

				it("$global::one", {
					vm.evalState.globalVars.get("$global::one").getIntValue().should.be(5);
				});

				it("$global::two", {
					vm.evalState.globalVars.get("$global::two").getIntValue().should.be(5);
				});

				it("$global::three", {
					vm.evalState.globalVars.get("$global::three").getIntValue().should.be(10);
				});

				it("$global::four", {
					vm.evalState.globalVars.get("$global::four").getIntValue().should.be(-10);
				});
			});

			describe("variables", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/variables.cs.dso");
				});

				it("$global", {
					vm.evalState.globalVars.get("$global").getIntValue().should.be(50);
				});

				it("$global::namespaced", {
					vm.evalState.globalVars.get("$global::namespaced").getIntValue().should.be(123);
				});
			});

			describe("while", {
				var vm:VM;

				beforeAll({
					vm = parseAndRunVM("tests/while.cs.dso");
				});

				it("$global should be int", {
					vm.evalState.globalVars.get("$global").getIntValue().should.be(110);
				});

				it("$global should be float", {
					vm.evalState.globalVars.get("$global").getFloatValue().should.be(110);
				});

				it("$global should be string", {
					vm.evalState.globalVars.get("$global").getStringValue().should.be("110");
				});
			});
		});
	}

	function parseAndRunVM(path:String) {
		var f = File.getBytes(path);
		var vm = new VM();
		vm.exec(path);
		return vm;
	}

	function execDirectory(path:String) {
		var files = FileSystem.readDirectory(path);

		for (file in files) {
			if (FileSystem.isDirectory(path + '/' + file)) {
				execDirectory(path + '/' + file);
			} else {
				if (Path.extension(file) == 'cs' || Path.extension(file) == 'gui' || Path.extension(file) == 'mcs') {
					var f = File.getContent(path + '/' + file);
					try {
						var compiler = new Compiler();
						var bytesB = compiler.compile(f);
						File.saveBytes(path + '/' + file + '.dso', bytesB.getBytes());
						trace('Compiled ${path}/${file}');
					} catch (e) {
						trace('Failed compiling ${file} ${e.details()}');
					}
				}
			}
		}
	}
}
