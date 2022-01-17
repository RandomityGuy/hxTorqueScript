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

	public function optimize(level:Int) {
		for (pass in optimizerPasses) {
			if (pass.getLevel() <= level)
				pass.optimize(ast);
		}
	}

	public function getAST() {
		return ast;
	}
}
