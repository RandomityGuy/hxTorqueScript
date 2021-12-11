$result::break = 0;

%x = 0;
while (%x < 10)
{
    %y = 0;
    while (%y < 10)
    {
        %z = 0;
        while (%z < 10)
        {
			$result::break = $result::break + %x + %y + %z;
            %z++;
		}

		if (%y == 5)
		{
			break;
		}

        %y++;
	}

    %x++;
}
