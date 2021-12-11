new SimGroup(Root1);
new SimGroup(Root2);

new SimGroup(Inner);

$result::Root[1, 0] = Root1.getCount();
$result::Root[2, 0] = Root2.getCount();

Root1.add(Inner);

$result::Root[1, 1] = Root1.getCount();
$result::Root[2, 1] = Root2.getCount();

Root2.add(Inner);

$result::Root[1, 2] = Root1.getCount();
$result::Root[2, 2] = Root2.getCount();
