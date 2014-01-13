In the [previous post][1] about the Puppet 3.5 experimental feature Puppet Types I covered
the `Class` and `Resource` types and that concluded the tour of all the currently available types.

This time, I am going to talk about what you can do with the types; the operators that
accept types as well as briefly touch on how types are passed to custom functions.

[1]:http://puppet-on-the-edge.blogspot.se/2013/12/class-and-resource-types.html

### The Match Operators

Almost all of the previous examples used the match operator `=~` so it should already
be familiar. When the RHS (right hand side) is a `Type`, it tests if the LHS (left hand side) 
expression is an instance of that type. Naturally `!~` tests if the LHS is not an instance
of the type.

### Equlaity Operators

The equality operators `==`, and `!=` also work on types. It should be
obvious that `==` tests if the types are equal and `!=` that they are not.
Equality for types means that they must have the same base type, and that they are
parameterized the same way - essentially "do they represent the same type?".

    Integer[1,10] == Integer[1,10] # true
    Integer[1,10] == Integer       # false
    Integer[1,10] != Integer[7,11] # true

### Comparison Operators

The comparison operators `<`, `<=`, `>`, `>=` compares the generality of the type (i.e.
if the type is more general or a subtype of the other type). As you may recall, `Object` is at the
top of the hierarchy and is the most general, so is is greater than all other types.

    Object > Integer          # true
    Object > Resource['file'] # true
    Integer < Object          # true
    
Compare these two expressions:

    Integer < Object         # true
    Integer =~ Type[Object]  # true

They basically achieve the same thing, the first by comparing the types, and the second
by first inferring the type of the LHS expression (i.e. `Type[Integer]`). Which operator
to use (match or comparison) depends on style, and if you have an instance or a type to begin with
etc.

There is currently (in what is on master as this is written) a difference in that
the comparison operators checks for *assignability* which always allows for undef. This may
change since the rest of the type system now has solid handling of undef / Undef, and it
currently produces the somewhat surprising result:

    Integer > Undef    # true

This because the operator is implemented as *"if an instance of the type on the right can be
assigned to something type constrained by the type on the left, then the right type is less than the left (or equal)"*

### In Operator

The in operator searches for a match of the LHS in the RHS expression. When the LHS is a `Type`
a search is made if RHS has an entry that is an instance of the type. With this it is very easy
to check say if there is an undefined element in an array:

    Undef in [1,2,undef]  # true
    String in [1,2,undef] # false
    
### Case Expression

The `case` expression also handles types. Normally, the case expression compares a test expression
against a series of options using `==` (or `=~` if the option is a regular expression). This
has been extended to also treat the case when the option is a `Type` as a match (i.e. an instance-of
match).

    case 3 {
      Integer : { notice 'an integer value' }
    }

If you do this using a Type:

    case Integer {
      Type[Integer] : { notice 'an integer type' }
    }

### Selector Expression

The selector expression treats types the same way as the case expression

    notice 3 ? {
      Integer => 'an integer value'
    }

    notice Integer ? {
      Type[Integer] => 'an integer type'
    }
 
### Interpolation

You can perform string interpolation of a type - it is simply turned into its string form:

    $x = Array[Integer]
    notice "the type is: $x"
    
    notice "the type is: ${Array[Integer]}"

Both print:

    Notice: Scope(Class[main]): the type is Array[Integer]
    
### Accessing attributes of a Resource

You can access parameters of an instance specific `Resource` type:

    notify { announcement: message => 'This works' }
    notice Notify[announcement][message]
    
prints:

    Notice: Scope(Class[main]): This works
    
Note that the use of this depends on evaluation order; the resource must have been evaluated
and placed in the catalog.

It is also possible to access the parameter values of a class using this syntax, but not
its variables. Again, this depends on evaluation order; the class must have been evaluated.
It must naturally also be a parameterized class.

### Summary, and some open issues

In this blog series I have described the new Puppet Type System that is available in
the experimental `--parser future` in Puppet 3.5. As noted in a few places, there may be
some adjustments to some of the details. Specifically, there are some outstanding issues:

* Should comparison operators handle undef differently?
* Should Regexp be treated as Data since it cannot be directly serialized?
* Do we need to handle Stage and Node as special types?
* Is there a need for a combined type similar to Variant, but that requires instances to
  to match all its types? (e.g. match a series of regular expressions)
* Is it meaningful to have a Not variant type? (e.g. Not[Type, Ruby, Undef])
* Should Size be a separate type (instead of baked into String, Array, Hash and Collection)?
* What are very useful types in say Scala, or Haskel that we should borrow?

### Playing with the examples

If you want to play with the type system yourself - all the examples shown in the series work
on the master branch of puppet. Simply do something like:

    puppet apply --parser future -e 'notice Awesome =~ Resource'
    

That's it for now.
