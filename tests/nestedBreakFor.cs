$result::break = 0;
for ($x=0;$x<10;$x++)
{
	for ($y=0;$y<10;$y++)
	{
		for($z=0;$z<10;$z++)
		{
			$result::break = $result::break + $x + $y + $z;
		}

		if ($y == 5)
		{
			break;
		}
	}
}
