Names
===
*Qualified Names* and *Qualified References* are used to refer to entities declared in a Puppet Program or to entities declared via plugins to the Puppet Runtime System.

A **Qualified Reference** is a reference to a type; one of:

* Built in types
* User defined resource type
* Resource type runtime plugin 
* A Puppet Class

A **Qualified Name** is a reference to a value (of some type), the type and scope depends on which operators are being used.

     $x  # name is a reference to the variable named 'x'
     sprintf("%x4", 256) # name is a reference to the function named 'sprintf'
     
Names and References are either *simple* consisting of a single identifier, or *qualified*, consisting
of a sequence of identifiers separated by `::` tokens. A qualified name/reference may start with `::` which makes the reference *absolute*.

In determining the meaning of a name or reference, the context of the occurrence is used to disambiguate among the various kinds of named elements.

Access control can be specified for a named element making this element only visible to a restricted set of contexts. Access control is a different from scope. Access specifies the part of the program
text within which the declared entity can be referenced by a qualified name/reference.

Declarations
---
A declaration introduces an entity into a program and introduces an identifier that can be used to refer to this entity. The ability to address an entity depends on where the declaration and
reference occurs - this is specified by Access Control and Scope.

A declared entity is one of the following:

* built in type
* plugin defined Resource type
* plugin defined Function
* (host) Class
* Class Parameter
* plugin defined Resource type parameter
* Variable
* Node
* Resource Instance

Scope of Declaration
---
The scope of a declaration is the region of the program within which the entity declared by the declaration can be referred to using a simple name, provided it is visible.

TODO: List of declarations and their scopes (W.I.P)

* All functions are always in scope
* All types are always in scope
* 
* The scope of a variable declaration in a Class is
* The scope of a Class


Shadowing and Obscuring
---
A local variable can only be referred using a simple name (never a qualified name).

It is not allowed to redeclare variables or parameters in the same scope.
A local scope may redeclare variables declared in outer scopes. These shadow the outer scope
declaration(s).

It is never allowed to declare a variable in a scope other than the current scope (i.e. it is
not possible to assign a value to a variable in another scope by using a qualified name).

TODO: Explain Shadow is a new declaration of an existing entity. Obscuring is the use of
a name in a context in such a way that it obscures something else in another scope (i.e. it is not
a shadow. THIS PROBABLY NEVERE HAPPENS IN PUPPET because variables are always $var (and type
references and names are differentiated by case).

Scopes
---
These constructs introduce a new scope:

* The Program's top scope
* A (host) Class
* A user defined Resource type
* A lambda
* A Node

### Top Scope

Top scope is created automatically when the execution of the program begins. Top scope
is the program region(s) outside of classes, user defined resource types, nodes and lambdas.

There is no difference between the top scope region in different source code files. There is
only one top scope.

### Class Scope

All Classes are singletons - there is never more than one instance of a given class. A parameterized
class may only be instantiated once - there can never be two instances of the same class with
different parameters in the same compilation.

Parameters and Variables in a Class C is in scope for C, and in all classes inheriting C.

All Parameters and Variables are by default public and are visible to all other scopes.
Parameters and Variables declared private are visible only to C.

### User Defined Resource Scope

A user defined resource type (like plugin defined resource types) may be instantiated multiple
times provided they are given unique names.

Parameters and Variables in a user defined resource type are always private - they are not visible
to any region outside of the resource type body.

TODO: Is this true; since it is possible to refer to the parameters of resource via
Resource[Type, title][param_name] - does that work for user defined resources as well?


Determining the meaning of a name
---
by context 

Access Control
---
keywords private and public applied to:
* class
* user defined type
* parameter
* variable
