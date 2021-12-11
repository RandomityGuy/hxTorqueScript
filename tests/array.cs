function arrayTest(%value)
{
    echo("INPUT: " @ %value);
    $result[1,2,3] = %value;
    echo("RESULT: " @ $result[1,2,3]);
}
arrayTest(5);
echo("AFTER: " @ $result[1,2,3]);
