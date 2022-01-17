package console;

@:publicFields
@:build(console.ConsoleObjectConstructorMacro.build())
class ConsoleObjectConstructors {
	static var constructorMap:Map<String, () -> ConsoleObject> = [];
}
