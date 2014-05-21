Here is a follow up post about the Puppet Type System Ruby API. The `Integer` type (as you may recall from the earlier posts) have the ability to represent a
range of values and the earlier posts showed how this can be used in the Puppet Language.
In this post, I will show you the Integer range features can be used from Ruby.

### Creating an Integer

If you do not remember, an `Integer` type with a range can be created in Ruby a couple of
different ways.

    # Using the type factory
    #
    FACTORY = Puppet::Pops::Types::TypeFactory
    range_t = FACTORY.range(100, 200)
    
    # Using the type parser
    #
    TYPE_PARSER = Puppet::Pops::Types::TypeParser.new
    range_t = TYPE_PARSER.parse('Integer[100,200]')

If you want to be explicit about an Infinite (open) range, use the symbol `:default` in Ruby, and the `default` Puppet language keyword in in the string representation given to the type parser.

The integer type's class is `Puppet::Pops::Types::PIntegerType`.

### Integer Type API

The Integer type has two attributes, from and to. In Ruby these values are either `nil` or have a Ruby `Integer` value. A value of `nil` means *negative infinity* in `from`, and *positive infinity* in `to`.

The `Integer` may also have a `to` value that is `<= from` (an inverted range).

The most convenient way to get the range in Numeric form is to call the method `range` which returns
an array with the two values with smallest value first, and where `nil` values are replaced by the corresponding +/- `Infinity` value.

### A Note About Infinity

`Infinity` is a special numeric value in Ruby. You can not access it symbolically, but it is the value that is produced by an operations such as `1/0`. The great thing about this value is that it can be used in arithmetic, and naturally; the result of any arithmetic operation involving Infinity is still Infinity. This makes it easy to test if something is in range without having to treat the unbound ends a special way.

The constants `INFINITY`, and `NEGATIVE_INFINITY` are available in `Puppet::Pops::Types` should
you need them for comparisons.

### Range Size

You can get the size of the range by calling `size`. If one of the to/from attributes is `Infinity`,
the size is `Infinity`.

### Iteration Support

The `PIntegerType` implements Ruby `Enumerable`, which enable you to directly iterate over its range. 
You can naturally use any of the iterative methods supported by `Enumerable`.

If one of the `to`/`from` attributes is `Infinity`, nothing is yielded (this to prevent you from iterating until the end of time).

    range_t = FACTORY.range(1,3)
    range_t.reduce {|memo, x| memo + x }  # => 6

### Getting the String Representation

All types in the Puppet Type system can represent themselves in `String` form in a way
that allows them to be parsed back again by the type parser. Simply call `to_s` to get the
String representation.

### Using Integer Range in Resources

Resources in the 3x Puppet Catalog can not directly handle `PIntegerType` instances. Thus, if
you like to use ranges in a resource (type), you must use the string representation as the values
stored in a resource, and then use the type parser to parse and interpret them as Integer values.

You can use the type system without also using the future parser for general parsing
and evaluation. The only requirement is that the RGen gem is installed. And if you are
going to use this in a Resource, you must also have RGen installed on the agent side. 
(In Puppet 4.0 the RGen gem is required everywhere).
