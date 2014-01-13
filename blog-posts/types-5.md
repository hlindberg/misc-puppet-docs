In the [previous post][1] about the Puppet 3.5 experimental feature Puppet Types I covered
the `Variant` and `Data` types along with the more special `Type` and `Ruby` types. Earlier posts
in this series provide an introduction to the type system, an overview of the types, a description
the general types Literal, Collection, Array, Hash etc.

This time, I am going to talk about the types that describe things that end up
in a Puppet catalog; `Class` and `Resource`, subtypes of `Resource`, and the common
super type `CatalogEntry`.

[1]:http://puppet-on-the-edge.blogspot.se/2013/12/variant-data-and-type-and-bit-of-type.html

### Type Hierarchy

Here is a recap of the part of the type system being covered in this post.

     Object
       |- CatalogEntry
       |  |- Resource[resource_type_name, title]
       |  |   |- <resource_type_name>[title]
       |  |
       |  |- Class[class_name]
       |  |- Node[node_name]
       |  |- Stage[stage_name]

### The Catalog Entry types in Puppet 3x

In Puppet 3x there is the notion of a reference to a class or resource type using
an upper cased word, e.g. `Class`, `File`. In 3x it is also possible to refer to a specific
instance of class or resource by using the `[]` operator and the title of the wanted instance.

So, in a way, Puppet 3x has a type system, just a very small one with a very limited set
of operations available.

### Backwards Compatibility

It was important that the new Type System was backwards compatible. All the existing puppet
logic is frequently using "resource references" and references to type using upper cased words.
It was very fortunate that it was possible to extended the "resource reference" syntax to
that of parameterized types (as explained in this series of blog posts). Popular type names
(like String, and Integer) did not collide with existing resource type names.

Hence, going forward, when there is an upper cased word (e.g. Class, File, Apache) you are looking
at a type, and when it is followed by a [] operator, it is a parameterized type.

The catalog entry types are slightly more special than the general type as it is possible to create
an array of types.

### The Catalog Entry Type

The CatalogEntry type is simply the common type for Class and Resource. It is not parameterized.

### The Class Type

The `Class` type represents *Puppet (Host) Class*. When not parameterized it matches all
classes. When parameterized with the name of a class it matches that class. When parameterized
with multiple class names the result is an array of `Class` type, each parameterized with a single
class name.

    class one { }
    class two { }
    
    Class[one] =~ Type[Class]      # true
    Class[one] =~ Type[Class[one]] # true
    Class[one] =~ Type[Class[two]] # false
    
    Class[one, two] =~ Array[Type[Class]]        # true
    Class[one, two] == [Class[one], Class[two]]  # true

The class name can be any string expression as long as the result is a valid class name.

### The Resource Type

The `Resource` type is the base type for all resource types (as they exist in Puppet 3x). The
`Resource` type is parameterized with a *type name* (e.g. 'File') when a reference to the
resource type itself is wanted, and with a *type name*, and one or more *titles* to produce
a reference to an instance (or array of instances) of the particular resource type. There is
no distinction between a resource type defined in a ruby plugin, or a user defined resource
type created with the `define` keyword in the Puppet Programming Language. The examples
below use the well known `File` resource type, but it could just as well be `MyModule::MyType`.

    file { '/tmp/a': }
    file { '/tmp/b': }
    
    Resource['File'] =~ Type[Resource['File']]  # true
    Resource['file'] =~ Type[Resource['File']]  # true
    
    Resource['file'] == File                    # true
    Resource[File] == File                      # true
    Resource[file] == File                      # true
    
    Resource[file, '/tmp/a'] == File['/tmp/a']                    # true
    Resource[file, '/tmp/a', '/tmp/b] == File['/tmp/a', '/tmp/b'] # true
    File['/tmp/a', '/tmp/b'] == [File['/tmp/a'], File['/tmp/b']]  # true
    File['/tmp/a', '/tmp/b'] =~ Array[Type[File]]                 # true
    Resource[file]['/tmp/a'] == File['/tmp/a']                    # true
    
As you can see, the syntax is quite flexible as it allows both direct (e.g. `File`) reference
to a type, and indirect (e.g. `Resource[<type-name-expression>]`). The type name is case insensitive.

The general rules in the type system are:

* A bare word that is upper cased is a reference to a type (e.g. `Integer`, `Graviton`)
* If the type is not one of the types known to the type system (e.g. `Integer`, `String`)
  then it is a `Resource` type name (e.g. `Graviton` means `Resource['graviton']`).
  
### Naming Advice

The set of known types in the type system may increase over time. If this happens they
will most likely represent (be named after) some well known data structure (e.g. `Set`, `Tree`) or computer science term (e.g. `Any`, `All`, `Kind`, `Super`). It is therefore
best to avoid such names when creating new resource types. `Resource` types typically represent
something far more concrete, so this should not be a problem in practice. In the unlikely event
there is a clash it is always possible to reference such resource types via the longer `Resource[<type-name>]` syntax.

This problem may also be remedied by the introduction of placing resource types inside a
module namespace. The type system is capable of handling this already, but the rest of the
runtime does not yet support this. (E.g. if you insist on having a resource type called 'String',
you could refer to it as `MyModule::String`.

Just to be complete; fully qualified resource type names works for user defined resource
types (i.e. when using the `define` keyword in the Puppet Programming Language).

### Node and Stage

And finally, I have reached the frontier of the development of the Type System.
The `Node` and `Stage` types are actually not yet implemented. The things they are intended to
represent do exist in the catalog, but it is a question about what they really are - just
specializations of resource types or something different?
This is something that will be sorted out in the weeks and months to come before Puppet 4.0 is
released.

### In the Next Post

So far, examples have only used a handful of expressions to operate on types - i.e. `==` `=~` and `[]`, and iteration. In the next post I will cover the additional operations that involve types `in`, comparisons with `<`, `<=`, `>`, `>=` and how types can be used in `case` expressions.
