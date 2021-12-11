function combined::test(%xMax, %yMax, %zMax)
{
    %result = 0;
    for (%x = 0; %x < %xMax; %x++)
    {
        for (%y = 0; %y < %yMax; %y++)
        {
            %z = 0;
            while (%z < %zMax)
            {
                %z = %z + 1;

                // Here is a comment on its own line
                echo("X: " @ %x @ " Y: " @ %y @ " Z: " @ %z);
                switch(%x)
                {
                    case 1:
                        %result = %result + 10;
                    case 2:
                        %result = %result * 2;
                    default: // Comment in another place
                        switch (%y)
                        {
                            case 3:
                                %result = %result + 1;
                            case 4: // Comment in a random place
                                switch(%z)
                                {
                                    case 10:
                                        %result = %result + 100;
                                    default:
                                        %result = -%result;
                                }
                        }

                }
            }
        }
    }

    return %result;
}

$result = combined::test(2, 3, 4);
echo("DONE: " @ $result);
