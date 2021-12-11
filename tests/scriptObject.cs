function MyCustomType::test(%this)
{
    return 32;
}

new ScriptObject(Testing)
{
    class = "myCUSTOMtYpE";
};

$result = Testing.test();
