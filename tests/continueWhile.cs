$result::continue = 0;

$i = 0;
while ($i < 10)
{
    if ($i >= 5)
    {
        $i++;
        continue;
    }
    $result::continue = $result::continue + $i;

    $i++;
}
