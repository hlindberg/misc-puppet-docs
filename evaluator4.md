Evaluator4
==========
This describes the "future evaluator" (Evaluator4).

Literals
---------
### String types

* Single quoted string
* Double quoted string - supports interpolation
* Heredoc

**TODO**

* Heredoc support (and templates) - changes in lexer and grammar
* Unicode support in strings (lexer needs to know \u) - requires Ruby 1.9

### Numeric types

* Integer
* Float

**TODO**

* PInteger, PFloat objects
* PInteger could keep track of radix for auto conversion/formatting to String - but
  operations effect on radix has not good heuristics. (Currently a LiteralNumber knows its
  radix, but it is immediately lost when evaluated to a number).
* PFloat could keep track of format/precision for boxing to String


### Names / Types

* A Name is an, optionally fully qualified, identifier (e.g. apache, apache::port)
* A Type is a fully qualified upper cased identifier (e.g. Integer, File, My_module::My_thing)

* Names may not have a segment that is a keyword.
* Names may not contain periods or hyphens.
* The rules for Types is the same as for Name (except that each segment starts with an upper case
  letter)

#### Hashes

We have to decide which classes can be used as keys (and values) in literal hashes. Since
evaluator 4 interprets a capitalized bare-word as a type, something like

    $myvar = { Some_thing => 'hai' } # => ok
    
Currently generates a syntax error since only text or name are allowed in the grammar. This
can be changed to also accept a type. If that change is made it
will map the type `Some_thing` to `hai`. Later when trying to retrieve this with:

    $myvar['Some_thing']   # undef
    
the result is `undef` since the type is not sql to the string.

Evaluator 4 is capable of using any type as a key (regexp, array, hash, type, numbers, string).
The question is if this should be limited to only Literals (see definition under types)?

Redmine:

* [#21117](https://projects.puppetlabs.com/issues/21117)
* [#14704](https://projects.puppetlabs.com/issues/14704)

### Auto Boxing

General auto boxing is problematic since numeric data needs to be formatted (hex, octal, decimal,
or precision, scientific notation) when being converted. Since general boxing is difficult it becomes a concern for each operator.

* Number => String
* String => Number
* Boolean => String
* Name => String
* Type => String

See discussion under other operators.

#### Undef
Undef will behave like nil in Ruby. It is a value/object, it is only special when it is
assigned to an attribute in a resource expression as this will be the same as not assigning
anything at all.

    This is debated. The problem is that it makes it impossible to specify that an 
    attribute should have no value unless that is its default. An empty string can be set for String
    attributes, but for numeric values there is no equivalent empty number.

Arithmetic Operators
--------------------
Puppet supports the conventional arithmetic operators:

* `+`
* `-`
* `*`
* `/`
* `%`
* `<<`
* `>>`

These operators perform arithmetic operations when applied to String, Integer or Float. A String is
boxed to a numeric type before the operation is carried out. It is an error if the String does not represent a number. The string form for a number is the same as for the Puppet language itself (octal, hex, decimal, or floating point formats).

Collection Operations
---------------------
Puppet supports the following operations as operators that perform operations on collections
(Array and Hash):

* `+`, concatenates arrays, merges hashes
* `-`, removes elements from arrays, removes keyed entries from hashes
* `<<`, appends to an array

The collection operations return new instances since collections are immutable.

    LHS must evaluate to an Array or a Hash (or it is a form of arithmetic expression)
    1,2,3] + [4,5,6] => [1,2,3,4,5,6]
    [1,2,3] + 4 => [1,2,3,4]
    [1,2,3] + {a => 10, b => 20} => [1,2,3, [a, 10], [b, 20]]
    {a => 10, b => 20} + {b => 30} => {a => 10, b => 30}
    {a => 10, b => 20} + {c => 30} => {a => 10, b => 30, c => 30}
    {a => 10, b => 20} + 30 => error
    {a => 10, b => 20} + [30] => error
    {a => 10, b => 20} + [c, 30] => {a => 10, b => 20, c => 30}


Comparison Operators
--------------------
The comparison operators are:

* `<`
* `>`
* `<=`
* `<=`
* `==`
* `!=`

Puppet 3x tries to be helpful by performing downcasing and boxing between String and Number but does
not apply this consistently. In 4x there is a decision to make; either continue being helpful (but without logical paradox) or letting the user be responsible (perform downcase, type conversion). Since shifting the responsibility to the user was considered to be more onerous and more breaking, thus the 4x comparison is performed as follows:

* If operands can be converted to numbers they are compared as numbers.
* Numbers are always lexicographically before strings, even if a string is empty.
* Strings are always compared in downcased form.
* Only scalars (String, Integer, Float) and Types can be compared.
* Types are compared using assignability (type compatibility)
* Type equality checks for identical type
* Objects other than Scalars have equality as defined per type
* Collections can be checked for equality, but are not comparable. The equality rules are applied
  to their elements, and if the two collections have the same size and equal elements they are 
  considered to be equal.

The downside is that it is not possible to compare verbatim strings. It also leaves questions about
international character sets unanswered. (In Ruby 1.8.7 there is certainly no internationalized downcase since there is no Unicode support).

In 4.x type conversion is implemented with the core function `convert` that takes a `PType` as its first argument, and then the object to convert (different conversions may take additional parameters such as converting an Integer to String with a particular radix.) These operations are all available as type operations in the evaluator. Example:

    String.convert(32, 16) # => "0x20"
    Boolean.convert("true") # => true
    
This unifies all type conversion and moves it into the core (from the various such conversion functions in stdlib and other modules.)

### Decision
Should 4x continue to be helpful (*as implemented*) or shift to a more conservative mode where
user is responsible for case independent comparison?. If so, the operators would be verbatim
compares, and a compare function would instead take options how to perform the comparison.

The opposite is also possible; add a function that is a verbatim compare (no downcase, no boxing).

### Puppet 3x
Puppet 3x has quirky rules for comparisons.

The `==` and `!=` operators use `evaluate_match` and delegates to the RHS of the expression!
This means that if a Regexp is found on the RHS it will do a match, not what is expected (luckily enough, there is no concrete syntax for this as a regexp can not be used after a == in 3x, but this is generalized in 4x as well as allowing different ways of creating a passing a regexp around as a value.

Secondly the comparison is done "downcased" `'a' == 'A'` if the evaluated LHS and RHS responds to downcase. (If only one side responds to downcast, the other side may still be downcased).

The same treatment is then performed on numbers, if a value is convertible to a number it is
converted to one. (The rule is not enforced to both if one is a number).

Lastly, values are equal if Ruby `==` or if :undef is compared against empty string.

The scalar comparisons converts to numbers, but does not perform downcasing! Which leads to the surprising logical paradox:

    'A' >= 'a' # false
    'A' == 'a' # true

The conversion to number makes it impossible to compare number like strings with text even if
the number is quoted.

    '07' > 'AAA'

Fails since Ruby cannot compare a Fixnum with a String.

Match Operators
---------------
    lhs =~ rhs
    lhs !~ rhs

* `lhs` must be a `String` or … See Decisions below

   - Note: Numbers must be converted to `String` using a radix since a regular expression match
     does not know if the representation is octal, decimal or hexadecimal, nor does it know how
     to format a floating point value into a string.

   - String interpolation uses decimal radix.

   - The function `sprintf` supports conversion of Integer and Float with several formatting options.

* `rhs` can be any expression that evaluates to a regular expression or a `String`:

    - a literal regular expression.

          $x =~ /Unit .* the end/

    - a regular expression created via the Pattern type.

          $x =~ Pattern['Until .* the end']

    - a regular expression created from a String or bare word, e.g 

          $x =~ "Until .* the end"
          $x =~ sodium

    - any expression evaluating to a regular expression

          $y = Pattern['Until .* the end']
          $x =~ $y
        
* The result is always a `Boolean`
* As a side effect, the match variables `$0`-`$n` are set in the current scope
  where `$0` represents the entire matched segment of the string, and `$1`-`$n`
  the match for each matched subexpression (indexed left to right in the regular expression).

### Discussion
Should a match against non string data result in false, or an error? It is really a user error, it is not meaningful to test against a number e.g. 0xFF + 0xFF =~ /F/ in 3x performs the test against the result in String form (which is decimal 510). It is however of value to not have to test when iterating over a data structure with numbers in them. In 3x all numbers are strings and hence a match would be attempted (and possibly succeed if user is aware of the rule). Another option is to return nil - it is not known if there is a match of not, and nil (i.e. undef) is never true.
  
  Select one of:
  
  * **Error** - *this is how it is implemented now*
  * Return **false**
  * Return **nil**/**undef**
  * Blindly convert to String and then match *this is what 3x does*
  * Implement PObject and track radix in integers and floats, all operations must have generality
    rules for radix. (Hex + Hex => Hex, etc.) Gets complicated, no clear heuristics. Format is 
    probably property of the variable/feature where value is assigned not the value itself.
    Probably not worth the effort.

### 3x Implementation Notes
#### Scope
The 3x scope has several issues in the match variable handling.

* If a sequence of matches is executed without being in a position that is a conditional expression (if, unless, case, etc.) one match scope is leaked per match. 

The outer match scopes are not guaranteed to be completely shadowed
by inner scopes, thus if an outer scope has a match for say $9, and there is no $9 in any inner scope, a request to lookup $9 will return the match from the outer scope.

* There are methods that are only used by tests (ephemeral?, remove all ephemerals, remove all levels of ephemerals. (They are unused, and if they were used in a real situation they would screw up the scope's ephemerals/local scope for lambdas)

IN operator
-----------
The `in` operator in Puppet 3x is a mysterious beast, it does not use the puppet rules for
equality and results in paradoxes. It is also not very versatile (it allows searching for a fixed substring in a string, but not a pattern, a not a substring in a collection of strings/keys.

The 4x in operator is enhanced to perform the following:

* String in String, searches for the LHS string as a substring in RHS (downcased)
* Number in String, is only true if the RHS == the number
* Any other type except Regexp in String is false
* Any type except Type and Regexp in Array is true if there is an array element == to the LHS
* Any type except Type and Regexp in Hash is true if there is a key == to the LHS
* Regexp in String, is true if the String matches the regexp
* Regexp in Array, is true if there is an array element that matches the Regexp
* Regexp in Hash, is true if there is a hash key that matches the Regexp
* The Regexp comparison skips non String entries
* Type in String, is false (cannot search for subtypes inside a string)
* Type in Collection searches for an assignable value (e.g. `Number in ['a', 1]`)
 
### Decision
A decision is needed how the `in` operator should work. There are several options:

* It uses the `==` operator to check for equality (*this is how it is now implemented* + special 
  rules as described above)
* It compares more strictly than `==` (a number is not equal to a number in string form), comparison
  is case sensitive. (*This is what 3x does*)
* Some other hybrid; strings in downcased form, but numbers != strings.
* Remove in favor of an iterator (e.g. `$x.select |$y| { $y == $z } != []`)

(*If the strict form is selected, then == should also be strict*)

### Puppet 3x
The Puppet 3x implementation is very simplistic and calls Ruby `:include?` which is a strict
verbatim `==` on the contained runtime objects. Hence logic like `'1' in [0x1, 01, '01']` is `false`.

Puppet 3x also requires the LHS to be a String. It is not possible to check if an array contains
another array (or any other data type for that matter).


[] Operator
-----------
The `[]` operator is versatile:

* access one or a range of elements from an Array
* access one or selection of keys from a Hash
* access a single character from a String
* access a range of characters (substring) from a String
* create a regexp when applied to a Pattern type
* create a specialized type when applied to a more generic type
* create a collection of types (for certain types)
* creates an array of integer given to, from, and optional step

### Array []
Examples:

    [1,2,3][2]      # => 2
    [1,2,3,4][1,2]  # => [2,3]
    [1,2,3][100]    # => nil
    [1,2,3,4][-1]   # => 4
    [1,2,3,4][2,-1] # => [3,4]

Fewer than 1 and more than 2 arguments to [] generates an error.

### Hash []
Examples:

    {'a'=>1, 'b'=>2, 'c'=>3}['b']         # => 2
    {'a'=>1, 'b'=>2, 'c'=>3}['b', 'c']    # => [2, 3]
    {'a'=>1, 'b'=>2, 'c'=>3}['x']         # => nil
    {'a'=>1, 'b'=>2, 'c'=>3}['x', 'y']    # => []
    {'a'=>1, 'b'=>2, 'c'=>3}['x', 'b']    # => [2]
    
Fewer than 1 arguments generates an error.
Note that the result of using multiple keys results in a compacted array where all missing entries
have been removed.

### String []
Examples:

    "Hello World"[6]    # => "W"
    "Hello World"[1,3]  # => "Hel"
    "Hello World"[6,-1] # => "World"

### Pattern []
Examples:

    $pattern = Pattern['(f)(o)(o)']  # => /(f)(o)(o)/
    'foo' =~ $pattern                # => true
    notice $1                        # => 'o'
    
### Operation on Types
#### Hash type
Examples:

    Hash[String]                     # => Hash[Literal, String] (type)
    Hash[String, Integer]            # => Hash[String, Integer] (type)
    $h = Hash[String]                # => Hash[Literal, String] (type)
    $h[]                             # => same type (null operation)

The specialized Hash type specializes value type if one key is given, and key, value types
if both are given. The key type is obtained from the LHS Hash. (A Hash is by default Hash[Literal, Data])
    
#### Array type
Examples:

    Array                            # => Array[Data]
    Array[String]                    # => Array[String] (type)
    $a = Array[String]               # => Array[String] (type)
    $a[]                             # => same type (null operation)

An Array is by default Array[Data], specialization overrides the LHS element type.
    
#### Class type
Examples:

    Class                            # => any class
    Class[apache]                    # => Class[apache] (reference to the class 'apache')
    Class[apache, nginx]             # => [Class[apache], Class[nginx]] (array of classes)
    $c = Class[apache]               # => Class[apache]
    $c[]                             # => same class (null operation)
    Class[apache][nginx]             # => error cannot make class more special
    
#### Resource type
Examples:

    Resource                           # => any resource type
    Resource[File]                     # => File
    Resource[File, '/tmp/x']           # => File['/tmp/x']
    Resource[File]['/tmp/x']           # => File['/tmp/x']
    Resource[File, '/tmp/x', '/tmp/y]  # => [File['/tmp/x'], File['/tmp/y']]
    File                               # => File
    File['/tmp/x']                     # => File['/tmp/x']
    File['/tmp/x', '/tmp/y']           # => [File['/tmp/x'], File['/tmp/y']]
    File['tmp/x']['/tmp/y']            # => error cannot make resource more special
    
The left hand type can be specialized, Resource to a specific type of resource, and a typed resource to a specific (titled) resource.

#### Integer type
Examples:

    Integer[1,3]      # => [1,2,3]
    Integer[3,1]      # => [3.2,1]
    Integer[1,6,2]    # => [1,3,5]
    Integer[6,1,2]    # => [6,4,2]
    Integer[1]        # => error
    Integer[]         # => Integer (null operation)
    
    Integer[1,3].each {|x| . . . }   # loop over result

Assignment
----------
There are three assignment operators in Puppet 4x:

* `=`
* `+=`
* `-=`

Regular assignment is the same in 4x as 3x; it is immutable; what is assigned in a scope can not be changed.

In 4x it is no longer possible to mutate a collection. It is illegal to assign to an index
in an array, or a key in a hash. Use hash merge to create a new hash with modified key. Create a new array by using function `collect`, splice new array by splitting `$a[from, to] + [newval] + $a[to+1, -1]`.

In 4x the `+=` operator is a shorthand such that `$a += expr` is the same as `$a = $a + expr`
Naturally, the referenced `$a` is from an outer scope for this to be meaningful.

The 4x `+=` evaluation is different than 3x in that the statement above in that it is consistent
with `+`.

* Concatenates Arrays and merges Hashes (and handles corner cases). See "Collection Operations"
* Sums numbers (boxing strings to numbers)
* Failing if strings can not be converted to numbers
* If referenced variable does not exist, the result is the given value

### Decide

* What is most helpful, to fail if referenced variable does not exist or produce given? (*The
  current implementation returns the given*).
* What is most helpful? Consistency w.r.t. `+` operator (+ is for numbers and collections, not 
  strings), or do odd things with numbers (it is impossible to do it correctly because of ambiguities 
  and missing radix) because string concatenation is very valuable.
  (*Current implementation is consistent*)
* Is it more helpful to always convert a non array/hash referenced value to an array with this
  single value - i.e. treat `+=` as "collection concatenate" 
* The `+=` operator is really superfluous now that `+` operates on arrays and hashes and can
  be removed. (This makes it more clear where the value comes from e.g. `$a = $::a + [1,2,3]`)
  

### The 3x implementation and assignment
The 3x implementation has problems with several data types. This is what 3x does:

* Always applies ruby `+` to referenced value with given value (this causes all the problems - see below)
* If the referenced variable is undefined an empty string is used instead
* If referenced is an Array the given must be an array or the operation fails
* If referenced is a Hash the given must be a Hash or the operation fails
* If the referenced is a String the given must be automatically convertible to a String (which is
  not any of the classes you care about - like numbers).
* If one of the sides is a number and the other not no boxing takes place), then the operation
  will fail.
* If $a is assigned the result of something that makes it a true number (functions, arithmetic, etc. 
  may have this result) it is possible to use `+=` if the given is a number. (surprise).
  
Taking += as String concatenation is odd since `+` is not string concatenation for strings (it should be written `$a = "${a} concatenated"`).

New Functions
-------------
There are functions that operate on specific types (`is_hash` is one example). Since there is now a type system it is easy to generalize the functions. These belong in core.

* `is_a(object, type)` - if the object is an instance of the type
* `type_of(object)` - returns the type of the object
* `convert_to(type, object, options)` - converts object to type (if possible)

(Functions for assignability between types can be added but are also handled via the comparison operators)

TODO: Implement the functions

String Interpolation
--------------------
The issue [#22593](http://projects.puppetlabs.com/issues/22593) screwed up ambitions to be
able to use if, unless, case expressions in interpolations since the interpolator did the wrong
thing for nested braces.

Now, the variables `$if`, `$unless`, `$undef`, `$true`, `$false`, and `$case` have to be written on the forms:

    "$if"
    "${$if}"

