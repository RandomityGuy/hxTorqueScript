function ifTest(%value)
{
    echo("GOT VALUE: " @ %value);

    if (%value == 0)
    {
        return 10;
    }
    else if (%value < 100)
    {
        return -10;
    }
    else if (%value < 200)
    {
        return 500;
    }
    else
    {
        return 200;
    }
}

$one = ifTest(0);
$two = ifTest(55);
$three = ifTest(320);
$four = ifTest(150);

echo("ONE: " @ $one);
echo("TWO: " @ $two);
echo("THREE: " @ $three);
echo("FOUR: " @ $four);
