package console;

@:build(console.ConsoleFunctionMacro.build())
class MathFunctions {
	static function solveLinear(a:Float, b:Float):{roots:Array<Float>} {
		if (a == 0)
			return {roots: []};
		return {roots: [-b / a]};
	}

	static function solveQuadratic(a:Float, b:Float, c:Float) {
		if (a == 0)
			return solveLinear(b, c);

		var discriminant = b * b - 4 * a * c;
		if (discriminant < 0)
			return {roots: []};
		else if (discriminant == 0) {
			return {roots: [-b / (2 * a)]};
		} else {
			var sqrtDiscriminant = Math.sqrt(discriminant);
			var den = 2 * a;
			return {roots: [(-b + sqrtDiscriminant) / den, (-b - sqrtDiscriminant) / den]};
		}
	}

	static function solveCubic(a:Float, b:Float, c:Float, d:Float) {
		if (a == 0)
			return solveQuadratic(b, c, d);

		// Normal form
		var A = b / a;
		var B = c / a;
		var C = d / a;

		var A2 = A * A;
		var A3 = A2 * A;

		var p = (1 / 3) * (((-1 / 3) * A2) + B);
		var q = (1 / 2) * (((2 / 27) * A3) - ((1 / 3) * A * B) + C);

		// use Cardano's fomula to solve the depressed cubic
		var p3 = p * p * p;
		var q2 = q * q;

		var D = q2 + p3;

		var num = 0;

		var roots:Array<Float> = [];

		if (D == 0) { // 1 or 2 solutions
			if (q == 0) { // 1 solution
				roots.push(0);
				num = 1;
			} else { // 2 solutions, but one negative
				var u = Math.pow(-q, 1 / 3);
				roots.push(2 * u);
				roots.push(-u);
				num = 2;
			}
		} else if (D < 0) { // 3 solutions
			var phi = (1 / 3) * Math.acos(-q / Math.sqrt(-p3));
			var t = 2 * Math.sqrt(-p);
			roots.push(t * Math.cos(phi));
			roots.push(-t * Math.cos(phi + Math.PI / 3));
			roots.push(-t * Math.cos(phi - Math.PI / 3));
			num = 3;
		} else {
			var sqrtD = Math.sqrt(D);
			var u = Math.pow(sqrtD - q, 1 / 3);
			var v = -Math.pow(sqrtD + q, 1 / 3);
			roots.push(u + v);
			num = 1;
		}

		// convert back to non-normal form
		for (i in 0...num) {
			roots[i] -= A / 3;
		}

		roots.sort((a, b) -> a > 0 ? 1 : a < 0 ? -1 : 0);

		return {roots: roots};
	}

	static function solveQuartic(a:Float, b:Float, c:Float, d:Float, e:Float) {
		if (a == 0)
			return solveCubic(b, c, d, e);

		// Normal form
		var A = b / a;
		var B = c / a;
		var C = d / a;
		var D = e / a;

		var A2 = A * A;
		var A3 = A2 * A;
		var A4 = A2 * A2;

		var sqrtA = Math.sqrt(A);
		var aCubed = A3 * A;
		var bSqrt = B * B;
		var cQuad = C * C;
		var dQuad = D * D;

		var p = ((-3 / 8) * A2) + B;
		var q = ((1 / 8) * A3) - ((1 / 2) * A * B) + C;
		var r = ((-3 / 256) * A4) + ((1 / 16) * A2 * B) - ((1 / 4) * A * C) + D;

		// use Cardano's fomula to solve the depressed cubic
		var p3 = p * p * p;
		var q2 = q * q;

		var D = q2 + p3;

		var num = 0;

		var roots:Array<Float> = [];

		if (r == 0) {
			var cbs = solveCubic(1, 0, p, q);
			roots = cbs.roots;
			roots.push(0);
		} else {
			var q2 = q * q;
			a = 1;
			b = (-1 / 2) * p;
			c = -r;
			d = (1 / 2) * r * p - ((1 / 8) * q2);

			var cbs = solveCubic(a, b, c, d);

			var z = cbs.roots[0];

			var u = (z * z) - r;
			var v = (2 * z) - p;

			if (u > 0) {
				u = Math.sqrt(u);
			} else {
				return {roots: []};
			}

			if (v > 0) {
				v = Math.sqrt(v);
			} else {
				return {roots: []};
			}

			a = 1;
			b = v;
			c = z - u;
			var qr1 = solveQuadratic(a, b, c);
			num = qr1.roots.length;

			a = 1;
			b = -v;
			c = z + u;
			var qr2 = solveQuadratic(a, b, c);
			num += qr2.roots.length;

			roots = qr1.roots.concat(qr2.roots);
		}

		// convert back to non-normal form
		for (i in 0...num) {
			roots[i] -= A / 4;
		}

		roots.sort((a, b) -> a > 0 ? 1 : a < 0 ? -1 : 0);

		return {roots: roots};
	}

	@:consoleFunction(usage = "(float a, float b, float c)", minArgs = 4, maxArgs = 4)
	static function mSolveQuadratic(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var a = Std.parseFloat(args[1]);
		var b = Std.parseFloat(args[2]);
		var c = Std.parseFloat(args[3]);
		var roots = solveQuadratic(a, b, c);
		return roots.roots.join(" ");
	}

	@:consoleFunction(usage = "(float a, float b, float c, float d)", minArgs = 5, maxArgs = 5)
	static function mSolveCubic(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var a = Std.parseFloat(args[1]);
		var b = Std.parseFloat(args[2]);
		var c = Std.parseFloat(args[3]);
		var d = Std.parseFloat(args[4]);
		var roots = solveCubic(a, b, c, d);
		return roots.roots.join(" ");
	}

	@:consoleFunction(usage = "(float a, float b, float c, float d, float e)", minArgs = 6, maxArgs = 6)
	static function mSolveQuartic(vm:VM, thisObj:SimObject, args:Array<String>):String {
		var a = Std.parseFloat(args[1]);
		var b = Std.parseFloat(args[2]);
		var c = Std.parseFloat(args[3]);
		var d = Std.parseFloat(args[4]);
		var e = Std.parseFloat(args[5]);
		var roots = solveQuartic(a, b, c, d, e);
		return roots.roots.join(" ");
	}

	@:consoleFunction(usage = "(float v) Round v down to the nearest whole number.", minArgs = 2, maxArgs = 2)
	static function mFloor(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.ffloor(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float v) Round v up to the nearest whole number.", minArgs = 2, maxArgs = 2)
	static function mCeil(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.fceil(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float v) Returns the absolute value of the argument.", minArgs = 2, maxArgs = 2)
	static function mAbs(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.abs(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float v) Returns the square root of the argument.", minArgs = 2, maxArgs = 2)
	static function mSqrt(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.sqrt(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float b, float p) Returns the b raised to the pth power.", minArgs = 3, maxArgs = 3)
	static function mPow(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.pow(Std.parseFloat(args[1]), Std.parseFloat(args[2]));
	}

	@:consoleFunction(usage = "(float v) Returns the natural logarithm of the argument.", minArgs = 2, maxArgs = 2)
	static function mLog(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.log(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float th) Returns the sine of th, which is in radians.", minArgs = 2, maxArgs = 2)
	static function mSin(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.sin(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float th) Returns the cosine of th, which is in radians.", minArgs = 2, maxArgs = 2)
	static function mCos(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.cos(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float th) Returns the tangent of th, which is in radians.", minArgs = 2, maxArgs = 2)
	static function mTan(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.tan(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float th) Returns the arc-sine of th, which is in radians.", minArgs = 2, maxArgs = 2)
	static function mAsin(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.asin(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float th) Returns the arc-cosine of th, which is in radians.", minArgs = 2, maxArgs = 2)
	static function mAcos(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.acos(Std.parseFloat(args[1]));
	}

	@:consoleFunction(usage = "(float rise, float run) Returns the slope in radians (the arc-tangent) of a line with the given rise and run.", minArgs = 3,
		maxArgs = 3)
	static function mAtan(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Math.atan2(Std.parseFloat(args[1]), Std.parseFloat(args[2]));
	}

	@:consoleFunction(usage = "(float radians) Converts a measure in radians to degrees.", minArgs = 2, maxArgs = 2)
	static function mRadToDeg(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Std.parseFloat(args[1]) * 180 / Math.PI;
	}

	@:consoleFunction(usage = "(float degrees) Convert a measure in degrees to radians.", minArgs = 2, maxArgs = 2)
	static function mDegToRad(vm:VM, thisObj:SimObject, args:Array<String>):Float {
		return Std.parseFloat(args[1]) * Math.PI / 180;
	}
}
