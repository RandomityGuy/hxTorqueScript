$result::continue = 0;
for ($i=0;$i<10;$i++)
{
	if ($i >= 5)
	{
		continue;
	}
    $result::continue = $result::continue + $i;
}
