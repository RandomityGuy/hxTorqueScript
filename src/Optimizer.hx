package;

import optimizer.ConstantFoldingPass;
import expr.Expr.Stmt;

class Optimizer {
	var ast:Array<Stmt>;

	var optimizerPasses:Array<IOptimizerPass>;

	public function new(ast:Array<Stmt>) {
		this.ast = ast;
		optimizerPasses = [new ConstantFoldingPass()];
	}

	public function optimize() {
		for (pass in optimizerPasses) {
			pass.optimize(ast);
		}
	}

	public function getAST() {
		return ast;
	}
}
