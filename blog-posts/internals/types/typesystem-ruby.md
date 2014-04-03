One question I got several times about the Puppet Type System is how it can be used from Ruby.
So, in this post I am going to show just that - how the type system can be put to good
use from within functions and in types and providers. This post is all about the
Puppet Type System's Ruby API.

### Background

The  Puppet Type System was first introduced in Puppet 3.4. The API and functionality has
been extended since then, and this blog post describes what is available in Puppet 3.5. The simple,
straight forward examples should also work in Puppet 3.4, but many of the more advanced types where implemented in 3.5.

The Type System is implemented using the rgen gem - so if you want to play with code
that uses the type system you should have that installed, and turn on --parser future to get
all the things needed loaded and ready.

### The Type System Implementation

At the core, the type system is built on a Type Model. This is what defines the classes
that describe a Type. This model is **anemic** (using a term I introduced in an [earlier post][1]) and the model is accompanied by two implementations - the `TypeFactory`, which is used to construct types, and `TypeCalculator` which performs computations involving type (is this object an instance of this type, are these types compatible, etc.).


[1]:http://puppet-on-the-edge.blogspot.se/2014/01/puppet-internals-separation-of-concerns.html

### The Type Factory

While it is possible to interact directly with the Type Model, it far more practical to do
so via the TypeFactory. One important thing to remember is that almost all of the types are
parameterized, and thus quite unique - the Integer type can describe a range, the String type
can express min and max length, etc. Thus, while there will be many instances describing a type
flowing around in the system that describe the same kind of thing, the actual type instances
are individual objects. In modeling terms, the parameters of a Type are contained in their parent
type Just like a specific wheel is mounted on one specific car (or no car) at any given point
in time is a specific Type instance associated with a parent type (or no type). This means that whenever we want to use a type we must have a fresh instance that is not already contained in
some other type. (This may change in the future, but complicates the modeling).

With that bit of theory taken care of, I can move on to showing examples.

Creating an instance of Integer:

    int_t = Puppet::Pops::Types::TypeFactory.integer()

(From this point forward, I am going to simplify the examples by assuming that `FACTORY` is a reference to `Puppet::Pops::Types::TypeFactory`.)

And, just to complete the example, to test if an object is an instance of that type we just
created:

    Puppet::Pops::Types::TypeCalculator.instance?(int_t, 3)        # true
    Puppet::Pops::Types::TypeCalculator.instance?(int_t, 'hello')  # false
    
(From this point forward, I am going to simplify the examples by assuming that `TYPES` is a 
reference to `Puppet::Pops::Types::TypeCalculator`.)

#### Factory methods

| method | description
|---|---|
| `integer` | creates an integer type range from -Infinity to +Infinity |
| `range(from, to)` | creates an integer type range with given from/to, where `:default` denotes Infinity |
| `float`   | creates a float type range from -Infinity to + Infinity |
| `float_range(from, to)` | creates a float type range with given from/to, where `:default` denotes Infinity |
| `string`  | creates a string type with size from 0 to Infinity |
| `enum(*strings)` | creates an enumeration type from the given set of strings |
| `pattern(patterns)` | creates an enumeration type based on regular expressions |
| `regexp(pattern=nil)` | creates a regexp type, optionally parameterized with a pattern |
| `boolean` | creates a boolean type |
| `scalar` | creates an abstract scalar type |
| `object` | creates an abstract object type |
| `numeric` | creates an abstract numeric type |
| `array_of(o)` | creates an array type parameterized by the given argument, its size is 0 to Infinity |
| `array_of_data` | creates an array parameterized by the abstract type Data, its size is 0 to Infinity |
| `hash_of(value, key_scalar)` | creates a hash parameterized by the given arguments for value and key, the default is a scalar key, its size is 0 to Infinity |
| `hash_of_data` | creates a hash parameterized with scalar key and Data value. |
| `collection` | creates a collection abstract type of size 0 to Infinity |
| `data` | creates the abstract Data type |
| `resource(type_name=nil, title=nil)` | creates a resource type, optionally parameterized with resource type name, and title |
| `host_class(class_name=nil)` | creates a host class resource type, optionally parameterized with a class name |
| `catalog_entry` | creates the abstract CatalogEntry type |
| `optional(t)` | creates a type that represents the given type t or undef |
| `variant(*types)` | creates a type that represents 'one of' the given types |
| `struct(type_hash)` | creates a Struct type that fully qualifies a hash |
| `tuple(*types)` | create a Type that fully qualifies an array |
| `ruby(o)` | creates a ruby type from the given object or class |
| `ruby_type(class_name)` | creates a ruby type representing the given Ruby class name |
| `undef` | creates a type representing undef values |
| `type_type(t=nil)` | creates a meta type, optionally parameterized with the type this is the meta type for |

In addition to these type creation methods, the `constrain_size` method allows changing the size 
constraint (for types that supports this; String, Array, Hash, and the occurrence of the last type in the Tuple type's sequence. The `type_of(o)` method is used by the other methods when converting the given argument(s) to type. The label(t) method produces a string representation of the type.

| method | description
| --- | ---|
| `constrain_size(t, from, to)` | constrains the size of t, where from and to are the same as for an integer range |
| `type_of(o)` is | produces a type for o using the rules shown below |
| `label(t)` | produces a string representation of the type. |

The type_of(o) method allows flexible specification of type parameters in Ruby, as specified by the
following table

| o is_a | then |
| --- | --- |
| `Class` | if the Ruby class corresponds to one of the Puppet types, e.g. String, Integer, and then then that type is returned, else a Puppet Ruby type.
| `PAbstractType` | used as is (i.e. `Puppet::Pops::Types::PAbstractType`) |
| `String` | the string is the classname of a Ruby class - the corresponding type is produced | 
| *any other* | the type is inferred using the **type calculator** (see below) |

Example:

    FACTORY.tuple(String, Integer)
    FACTORY.struct({'a' => String, 'b' => Integer})

    # i.e. instead of having to do this
    FACTORY.tuple(FACTORY.string, FACTORY.integer)
    
In summary - the type factory creates types using convenient transformation from Ruby types
to Puppet types. (For details about each method, see the yardoc for the `TypeFactory`). For more information about what the different types represents, see the earlier posts in this series
about the [Puppet Type System][2]

[2]:http://THE_TYPE_SYSTEM

### The Type Calculator

The other major part of the Puppet Type implementation is the class Puppet::Pops::Types::TypeCalculator (from this point on referred to as CALCULATOR in examples). The type calculator is the type inference system.
    
The type calculator has the same set of methods available both as instance and class methods.
If a long series of operations are to be performed, it is faster to call the singleton method to
get an instance, and then use what is returned for multiple operations.

The set of methods are:

| method | description |
| --- | --- |
| `assignable?(t, t2)` | is t the same, or a more general type than t2 |
| `instance?(t, o)` | is o an instance of the type t |
| `equals(t, t2)` | is the type t equal to the type t2 |
| `enumerable(t)` | if the type is Enumerable an suitable Enumerator is produced, else nil (currently only for integer range) |
| `infer(o)` | infers the type of o and produces a generalized type (see below) |
| `infer_set(o)` | infers the type of o and produces a value dependent type set (see below) |
| `singleton` | returns the single instance of the TypeCalculator |
| `string(t)` | produces a s string representation of the given type. This is the same as calling `to_s` on a type instance |

In addition to these methods, there are several utility methods, mostly for use by the
type calculator itself - those are not considered to be API.

The set of methods makes it possible to perform all of the operations exposed in the
Puppet Programming Language.

The use of most of these methods should be easy to grasp. The `assignable?` method performs
a type check based on two types, and `instance?` on a type and an instance.

The `infer` method infers a generalization - e.g. given `[1, 3.14]` infers `Array[Numeric]`, whereas
the `infer_set` method infers a set of value dependent types, e.g. given `[1, 3,14]` it will produce
an `Array[Variant[Integer[1,1], Float[3.14, 3.14]]]` where each value in the array is encoded as a unique type. This is what allows more detailed type-questions to be answered.

### The Type Parser

The third and final component in the Type System is the `TypeParser`. It produces a type
given its string representation - e.g. if you execute the example below, you get back
the same type:

    a_type = FACTORY.array_of(String)
    Puppet::Pops::Types::TypeParser.new.parse(a_type.to_s)

This allows you to store / pass type information in String form in a Resource parameter and convert 
it back to a type again in a Provider. Same thing for facts, settings, or when you get data
from a source that cannot produce type instances. 

### Other Operations on Type

The types themselves support equality (`==`, `eql?`), and they can be used as hash keys - 
two types that are equal hash to the same hash-key. You can also copy a type (and all of its parameters) using the `copy` method (which is important as you need to consider the containment rule).

The `Regexp` type has a method called `regexp` that returns a Ruby Regexp from the puppet type's
pattern.

The `Struct` type has a method to obtain the name/type hash as a Ruby `Hash`.

All types are considered to be immutable once they have been fully constructed, but this is not
(currently) enforced.

### Typical Usage

Say we want to check the types of arguments given to a puppet function. In this case we can
perform all the type checking in one go even for complex types (just calling instance?).

    accepted_t = FACTORY.tuple(String, Integer)
    unless CALCULATOR.instance?(accepted_t, arguments)
      raise ParseError, "Argument type mismatch. Expected: " + 
         accepted_t.map(&:to_s).join(', ') +
         ". Got: " +
         CALCULATOR.infer_set(arguments).map(&to_s).join(', ')

That is, if we accept two arguments of String and Integer type respectively this will
print out what we expected and what we got. (Here I did go through the gymnastics of
turning the types back to string even if this could have been written out directly as
just "String, Integer").

If the function supports
multiple signatures, we can obtain the type of the given argument by calling `infer_set`, and then
test assignability of that against the signatures - this is faster than performing multiple
`instance?` calls, as each call will need to infer the type of the given arguments from
scratch.

    given_t = CALCULATOR.infer_set(arguments)
    case
    when CALCULATOR.assignable?(signature_1_t, given_t)
      # process signature 1
    when CALCULATOR.assignable?(signature_2_t, given_t)
      # process signature 2
    else
      # error, not a supported signature
    end

Now the gymnastics from before makes more sense since we may want to print the various signatures
and state that the given did not match any of them. 

### Future Work

There is a new Function API in the works that will make use of the Type System, and it will
also contain providing good error messages when there is a type mismatch. Until then, manual
checking can be done as shown above.

There may be changes to how the containment of parameters work - right now the same type instance
may have to be repeated multiple times, and it would be beneficial to be able to declare them
by name and then reference rather than contain them.