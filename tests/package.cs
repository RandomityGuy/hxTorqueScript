function getNumber()
{
    return 1;
}

function namespaced::getNumber()
{
    return 2;
}

package a
{
    function getNumber()
    {
        return parent::getNumber() + 1;
    }

    function namespaced::getNumber()
    {
        return parent::getNumber() + 2;
    }
};

package b
{
    function getNumber()
    {
        return parent::getNumber() + 1;
    }

    function namespaced::getNumber()
    {
        return parent::getNumber() + 2;
    }
};

$before = getNumber();
$beforeNamespace = namespaced::getNumber();
activatePackage(a);
$afterA = getNumber();
$afterANamespace = namespaced::getNumber();
activatePackage(b);
$afterB = getNumber();
$afterBNamespace = namespaced::getNumber();
