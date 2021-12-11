function whileLoopTest(%initializer)
{
    $global = %initializer;

    %iteration = 0;
    while ($global < 100)
    {
        echo("Current Global: " @ $global);

        $global = $global + %iteration;
        %iteration = %iteration + 1;
    }
    echo("Result: " @ $global);
}
whileLoopTest(5);
