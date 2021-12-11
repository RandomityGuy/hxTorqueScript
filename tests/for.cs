function forLoopTest(%initializer)
{
    $global = 5;
    for(%iteration=0; %iteration < 10; %iteration++)
    {
        echo("Current Global: " @ $global);
        $global = $global + %iteration;
    }
    echo("Result: " @ $global);
}
forLoopTest(5);
echo("AFTER: " @ $global);
