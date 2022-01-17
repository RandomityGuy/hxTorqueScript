function normalFunction(%a, %b, %c)
{
	return %a + %b * %c;
}

function SimObject::boundFunction(%this, %a, %b, %c)
{
	// %this should be ID 0 going into this given no other init has occurred
	return %this + %a + %b * %c;
}

$result::normalFunction = normalFunction(1, 2, 3);

new SimObject(Test);
$result::boundFunction = Test.boundFunction(1, 2, 3);
