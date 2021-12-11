function switchCaseTest(%index)
{
    $some::Global = 500;
    switch (%index)
    {
        case 1:
            return 5;
        case 2:
            return 5;
        case 3:
            return 5;
        case $some::global:
            return 10;
    }

    return -10;
}

$global::one = switchCaseTest(1);
echo($global::one);
$global::two = switchCaseTest(2);
echo($global::two);
$global::three = switchCaseTest(500);
echo($global::Three);
$global::four = switchCaseTest(600);
echo($global::four);
