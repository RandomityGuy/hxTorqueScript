function FileObject::chainXYZ(%this, %x, %y, %z)
{
    return %this.field[%x, %y, %z];
}

function FileObject::chain(%this)
{
    return %this.field;
}

new FileObject(A);
A.field = new FileObject(B);
B.field[1,2,3] = new FileObject(C);

//echo(B.field[1,2,3]);

echo(A.chain().chainXYZ(1, 2, 3)); //.field[1,2,3]);
