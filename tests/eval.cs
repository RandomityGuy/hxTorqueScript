$result = eval("return 1 + 1;");
$result2 = eval("$next = 1; return 3;");
echo($result);
echo($result2);
echo($next);
$result3 = eval("eval(\"eval(\\\"echo(\\\\\\\"This is bruh\\\\\\\");\\\");\");");