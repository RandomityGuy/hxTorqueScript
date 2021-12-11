$result::continue = 0;
for (%x=0;%x<10;%x++)
{
	for (%y=0;%y<10;%y++)
	{
		if (%y >= 5)
		{
			continue;
		}

		for(%z=0;%z<10;%z++)
		{
			$result::continue = $result::continue + %x + %y + %z;
		}
	}
}
