In the [previous post][1] about the Puppet 3.5 experimental feature Puppet Types I presented
and overview of the types in the Puppet Type System and provided details about
the Literal types.

This time, I am going to present `undef` - what it means to have undefined value, and
what it means when something is empty. At least from a type perspective.

[1]:http://http://puppet-on-the-edge.blogspot.se/2013/12/the-type-hierarchy-and-literals.html

### Let's talk about Undef

All computer languages have to deal with "undefinedness"; a variable that has no value, an
array or hash that is empty, a hash with no value for a key. When the language also has the ability
to use a symbol to denote the "undefinedness" it gets more complicated since it is now also
represented by a value and it can be used as the value of variable, as a key or value in a hash
entry etc.

### Only undef is Undef

To start out simple, the literal `undef` in the Puppet Language is the only thing that is
an instance of the `Undef` type. We can easily confirm this:

     undef =~ Undef     # true
     1     =~ Undef     # false
     hi    =~ Undef     # false
                        # etc.
                        
The `undef` value is also an `Object`.

     undef =~ Object    # true

The value undef is also produced when something looked up does not have a value.

     $hsh = { a => 10 }
     $hsh[b] =~ Undef    # true
     
So far, this is quite straight forward. The fun starts when considering collections of
values that may be empty, contain a mix of values and undef etc.

### Combining undef with values

When the type system performs *type inference* (the act of figuring out the type of values) it
will combine types to produce a single type that describes the value / values. It does this by
widening (i.e. making the type more general). Say, if we combine an `Integer` with a `Float`, the
inference will return `Numeric`, since that is the type that is general enough to describe both
of them. When `undef` is involved, the only more general type is `Object`.

     [1, 3.14]  =~ Array[Numeric]  # true
     [1, undef] =~ Array[Numeric]  # false
     [1, undef] =~ Array[Object]   # true
     
We now have a problem if we do not want to accept all kinds of objects just because we
want to accept `undef` values among the numbers.
Luckily, the type system has a type called `Optional` that does exactly what we want in
this situation, it accepts something of a specific type or `Undef`.

     [1, undef]    =~ Array[Optional[Numeric]] # true
     [1, a, undef] =~ Array[Optional[Numeric]] # false
     
In case you wonder, if the array only contains `undef` values, its type is `Array[Undef]`.

     [undef, undef] =~ Array[Undef]  # true
     
### Emptiness

"Emptiness" is very much related to "Undefinedness". As an example - what is the type of the elements 
of an empty array? Clearly, there is a difference between an empty array and an array containing `undef` values.

The type system handles this by using a different quality of the array; its *size*. The concept is
generalized; Collection, Array, Hash, and String are types that consider the size of values - they
are said to be *sized types*. 

* By default a sized type allows the instance to be empty up to infinite size.
* An empty sized collection (array, hash) has an element type that matches any type

Here are some examples:

     [] =~ Array[Integer]         # true
     [] =~ Array[String]          # true
     {} =~ Hash[Literal, String]  # true
     
We can make this behave in a strict way by also constraining the size - read on...
     
### Constraining the Size

The Type System supports constraining the size of the sized types. This is done by using a range
(like we have already seen when expressing Integer and Float ranges).

We an specify that a String should not be empty:

     String[1]        # at least one character
     '' =~ String[1]  # false
     
We can cap the upper limit:

     String[1,80]           # min 1, max 80 characters
     'abcd' =~ String[1,3]  # false, too long
     
For an `Array` the limit comes after the type:

     Array[Integer, 1]      # at least one Integer
     Array[Integer, 1, 10]  # at least one Integer, at most 10
     
The same is true for `Hash`:

     Hash[Literal, Integer, 1]      # at least one Integer entry
     Hash[Literal, Integer, 1, 10]  # at least one Integer entry, at most 10

The `Collection` type also accepts a range (but no type).

    Collection[1]  # i.e. a non-empty collection (array or hash)

The range can be specified as one or two integer values, using a literal `default`, by giving
an `Integer` type with a range, or an array containing the values. This means you can do
things like these:

    $range = Integer[1,10]
    $arr =~ Array[Integer, $range]
    
    $range = [$from, $to]
    $arr =~ Array[Integer, $range]

### In the Next Post

In the next post I am going to talk about the `Variant`, and `Data` types - types that represent
a selection of other types and how they can be used.