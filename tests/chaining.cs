new FileObject(Root);
Root.A = new FileObject();
Root.A.B[1,2,3] = new FileObject();
Root.A.B[1,2,3].C = new FileObject();

$result::root = Root.getID();
$result::a = Root.A.getID();
$result::b = Root.A.B[1,2,3].getID();
$result::c = Root.A.B[1,2,3].C.getID();
