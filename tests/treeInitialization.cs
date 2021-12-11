new SimSet(Root)
{
    field = new SimGroup(field);

    new SimSet(ChildRoot)
    {
        childField = new SimGroup(childField);

        new SimSet(Child)
        {
            testField = 5;
            childArrayField[1, "A", 2] = new SimGroup(childArrayField);
        };
    };
};

// Set result values
$root::field = Root.field.getName();
$root::ChildRoot = Root.getObject(0).getName();
$root::childField = Root.getObject(0).childField.getName();
$root::child = Root.getObject(0).getObject(0).getName();
$root::childArray = Root.getObject(0).getObject(0).childArrayField[1, "A", 2].getName();
