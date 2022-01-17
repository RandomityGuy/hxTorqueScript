function SimObject::chainXYZ(%this, %x, %y, %z)
{
    return %this.field[%x, %y, %z];
}

function SimObject::chain(%this)
{
    return %this.field;
}

new SimObject(A);
A.field = new SimObject(B);
B.field[1,2,3] = new SimObject(C);

//echo(B.field[1,2,3]);

$result = A.chain().chainXYZ(1, 2, 3); //.field[1,2,3]);
