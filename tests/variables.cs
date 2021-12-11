function variablesTest()
{
    %local = 50;
    $global = %local;

    %local::namespaced = 123;
    $global::namespaced = %local::namespaced;

    echo("GLOBAL: " @ $global);
    echo("GLOBAL NAMESPACE: " @ $global::namespaced);
}
variablesTest();
