$result::break = 0;

$i = 0;
while ($i < 10)
{
    $result::break = $result::break + $i;
    $i++;

    if ($i == 5)
    {
        break;
    }
}
