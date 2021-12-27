# hxTorqueScript
A DSO bytecode compiler for the TorqueScript language used for scripting in Torque Game Engine.  


# Info
Currently, only DSO bytecode version 33 (Torque Game Engine 1.2) has been implemented.  
There is no optimization done on the resulting bytecode and it is identical to the output given by Torque Game Engine.  
The repo does not contain the TorqueScript VM. That is a WIP.

# Building
Haxe 4 and the Haxe HashLink runtime is required.
```
haxe build.hxml
```
This build.hxml can be modified to output the source to various other languages.

You can also transpile it directly to C using HashLink/C and compile that.
```
haxe build-c.hxml
```
The instructions after that are in https://gist.github.com/Yanrishatum/d69ed72e368e35b18cbfca726d81279a

# Usage
Presuming you already have HashLink installed and you have built it:
```
hl bin/main.hl <path/directory> [-d] [-v[atr]]

<path/directory>: The path to the file to compile to DSO, or the folder which will be recursively search for .cs/.gui TorqueScript files and compile it.
-d: Disassemble mode, Input in the DSO file/directory and it will disassemble it into human readable DSO instructions
-v: Used to explicitly change the verbosity of the DSO disassembly. Append a, t, r, or a combination of them or none of them to modify the verbosity, by default without the -v flag, all of the below are enabled.
    a: Enables dumping of instruction arguments
    t: Enables dumping of the constant value tables
    r: Enables fancy printing of constant table references
```