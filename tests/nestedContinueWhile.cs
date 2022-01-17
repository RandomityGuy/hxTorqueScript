$result::continue = 0;

$x = 0;
while ($x < 10)
{
    $y = 0;
    while ($y < 10)
    {
		if ($y >= 5)
		{
            $y++;
			continue;
		}

        $z = 0;
        while ($z < 10)
        {
			$result::continue = $result::continue + $x + $y + $z;
            $z++;
		}

        $y++;
	}

    $x++;
}
