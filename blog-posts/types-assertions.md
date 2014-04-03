Stdlib Module vs. Puppet Future Parser / Evaluator

[Earlier in this series][1] of blog posts about the future capabilities of Puppet, and
the Puppet Type System in particular, you have seen how the
match operator can be used to check the type of values. In Puppet 3.6 (with --parser future)
there is a new function called `assert_type` that helps with type checking. This led to
questions about the existing functionality in the puppetlabs-stdlib module, and how the
new capabilities differ and offer alternatives.

In this post I am going to show examples of when to use type matching, and when to use the new `assert_type` function as well as showing examples of a few other stdlib functions and
how the same tasks can be achieved with the future parser/evaluator available in Puppet 3.5.0
and later.

[1]: http://puppet-on-the-edge.blogspot.se/2014/02/the-puppet-type-system-blog-posts.html

### The Stdlib is_xxx functions

The puppetlabs-stdlib module has several functions for checking if the given value is
an instance of a particular type. Here is a comparison:

| stdlib           | type system |
| ---              | ---         |
| `is_array($x)`   | `$x =~ Array` |
| `is_bool($x)`    | `$x =~ Boolean` |
| `is_float($x)`   | `$x =~ Float` |
| `is_hash($x)`    | `$x =~ Hash` |
| `is_integer($x)` | `$x =~ Integer` | 
| `is_numeric($x)` | `$x =~ Numeric` | 
| `is_string($x)`  | `$x =~ String` | 
| n/a  | `$x =~ Regexp` | 

Note that the type system operations does not coerce strings into numbers or vice versa. It
also does not make a distinction about how a number was entered (decimal, hex, or octal). The
stdlib functions vary in their behavior, but typically only treat strings with decimal notation
as being numeric or integer (which is both wrong and confusing).

In addition to the basic type checking shown in the table above, you can also match against
parameterized types to perform more advanced checks; range of numeric values, checking
the size of an array, the size and type of elements in an array, arrays with a sequence of different types (i.e. using the `Tuple` type). You can do the same for `Hash` where the `Struct` type allows specification of expected keys and their respective type). See [the earlier posts in this series][1] for how to use those types.

### The Stdlib validate_xxx functions

The puppetlabs-stdlib module has several functions to validate if the given value is
an instance of a particular type. If not, an error is raised. The new `assert_type` function does
the same, but it checks only one argument, and thus if you want to check multiple values at ones,
you place them in an array, and then check against an Array type parameterized with the type
you want each element of the array to be an instance of. Here are examples:

| stdlib                     | type system
| ---                        | ---         
| `validate_array($x)`       | `assert_type(Array, $x)`                
| `validate_array($x, $y)`   | `assert_type(Array[Array], [$x, y])`
| `validate_bool($x)`        | `assert_type(Boolean, $x)`
| `validate_bool($x, $y)`    | `assert_type(Array[Boolean], [$x, $y])`
| `validate_hash($x)`        | `assert_type(Hash, $x)`
| `validate_hash($x, $y)`    | `assert_type(Array[Hash], [$x, $y])`
| `validate_re($x)`          | `assert_type(Regexp, $x)`
| `validate_re($x, $y)`      | `assert_type(Array[Regexp], [$x, $y])`
| `validate_string($x)`      | `assert_type(String, $x)`
| `validate_string($x, $y)`  | `assert_type(Array[String], [$x, $y])`

Note that the `Regexp` type only matches regular expressions. If the desire is to assert
that a `String` is a valid regular expression it can be
given as a parameter to the `Regexp` or `Pattern` type since it performs a regular expression compilation of the pattern string, and raises an error with details about the failure. 

    'foo' = Pattern["{}[?"] # this will fail with error
    
Note that the 3.5.0 --parser future does not validate the regular expression pattern until it
is used in a match (not when it is constructed). This is fixed in Puppet 3.6.

### The validate_slength function

The validate_slength function is a bit of a Swiss Army knife and it allows validation
of length in various ways for one or more strings. It has the following signatures:

    validate_slength(String value, Integer max, Integer min) - arg count {2,3}
    validate_slength(Array[String] value, Integer max, Integer min) - arg count {2,3}

To achieve the same with the type system:

    # matching (there is no is_xxx function for this)
    $x =~ String[min, max]
    [$x, $y] =~ Array[String[min, max]]
    
    # validation
    assert_type(String[min,max], $x)
    assert_type(Array[String[min,max]], [$x, $y])

A common assertion is to check if a string is not empty:

    assert_type(String[1], $x)

### The Stdlib values_at function

The stdlib function values_at, can pick values from an array given a single index value, or
a range. The same can now be achieved with the `[]` operator by simply giving it a range.


| stdlib                           | future parser
| ---                              | ---         
| `values_at([1,2,3,4],2)`         | `[1,2,3,4][2]`       
| `values_at([1,2,3,4],["1-2"])`   | `[1,2,3,4][1,2]`       

The `values_at`, allows picking various values by giving it an array of elements to pick. This
is not supported by the `[]` operator. OTOH, if you find that you often need to pick elements 1,6, 32-38, and 164 from an array, you are probably not doing it right.

### The Stdlib type function

The type function returns the name of the type as a lower case string, i.e. 'array', 'hash', 'float', 'integer', 'boolean'. This stdlib function does not perform any inference or details
about the types, it only returns the type name of the base type.

When writing this, there is currently no corresponding function for the new type system, but
a `type_of` function will be added in 3.6 that returns a fully inferred Puppet Type (with all
details intact). When this function is added it may have an option to make the type generic
(i.e. reduce it to its most generic form).

The typical usage of type is to... uh, check the type - this is easily done with the match operator:

| stdlib                       | future parser
| ---                          | ---         
| `type($x) == string`         | `$x =~ String`       

### The Stdlib merge, concat, difference functions

Merging of hashes an concatenation of arrays can be performed with the `+` operator instead
of calling `concat` and `merge`. The `-` operator can be used to compute the difference.

| stdlib                | future parser
| ---                   | ---         
| `merge($x,$y)`        | `$x + $y`       
| `concat($x,$y)`       | `$x + $y`
| `diff($x,$y)`         | `$x - $y`

### Other functions

There are other functions that partially overlap new features (like the `range` function), but
where the new feature does not completely replace the functionality provided by the function.
There is also the possibility to enhance some of the functions to give them the ability to accept
a block of code, or to make use of the type system.

At some point during the work on Puppet 4x we will need to revisit all of the stdlib functions.


