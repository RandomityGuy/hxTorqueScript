new SimSet(Root)
{
    new SimSet(ChildRoot)
    {
        new SimSet(Child)
        {
            testField = 5;
        };
    };
};

Root.field = new SimGroup(field);
ChildRoot.childField = new SimGroup(childField);
Child.childArrayField[1, "A", 2] = new SimGroup(childArrayField);


// Set result values
$root::field = Root.field.getName();
$root::ChildRoot = Root.getObject(0).getName();
$root::childField = Root.getObject(0).childField.getName();
$root::child = Root.getObject(0).getObject(0).getName();
$root::childArray = Root.getObject(0).getObject(0).childArrayField[1, "A", 2].getName();
