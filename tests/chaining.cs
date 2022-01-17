new SimObject(Root);
Root.A = new SimObject();
Root.A.B[1,2,3] = new SimObject();
Root.A.B[1,2,3].C = new SimObject();

$result::root = Root.getID();
$result::a = Root.A.getID();
$result::b = Root.A.B[1,2,3].getID();
$result::c = Root.A.B[1,2,3].C.getID();
