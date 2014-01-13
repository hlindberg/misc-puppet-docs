In the [previous post][1] about the Puppet 3.5 experimental feature Puppet Types I covered
the rationale behind having a type system, and exemplified by using a handful of types such as `Integer`, and `Array` to achieve simple tasks.

This time, I am going to present an overview of all the types in the type system and present
the most fundamental type - the Literals in more detail.

[1]:http://puppet-on-the-edge.blogspot.se/2013/12/what-type-of-type-are-you.html

### The Type Hierarchy

<? prettify language=rb?>

     Object
       |- Literal
       |  |- Numeric
       |  |  |- Integer[from, to]
       |  |  |  |- (Integer with range inside another Integer)
       |  |  |
       |  |  |- Float[from, to]
       |  |  |  |- (Float with range inside another Float)
       |  |
       |  |- String
       |  |  |- Enum[*strings]
       |  |  |- Pattern[*patterns]
       |  |  |- Regexp[regexp]
       |  |
       |  |- Boolean
       |  |- Regexp
       |
       |- Collection[size_from, size_to]
       |  |- Array[element_type, size_from, size_to]
       |  [  |- (type compatible array with size within range)
       |  |
       |  |- Hash[key_type, value_type, size_from, size_to]
       |     |- (type compatible hash with size within range)
       |
       |- Data
       |  |- Literal
       |  |- Array[Data]
       |  |- Hash[Literal, Data]
       |
       |- CatalogEntry
       |  |- Resource[resource_type_name, title]
       |  |- Class[class_name]
       |  |- Node[node_name]
       |  |- Stage[stage_name]
       |
       |- Variant[*types]
       |- Optional[type]
       |- Undef
       |
       |- Type[T]
       |
       |- Ruby[class_name]

### Meet the Literals

The types under `Literal` should not come as a surprise; they represent something of *single value*
such as `String`, `Integer`, `Float`, `Boolean` and `Regexp` (regular expression).

<? prettify language=rb?>

     'hello' =~ String  # true
     '123'   =~ String  # true
     '123'   =~ Numeric # false
     123     =~ Numeric # true
     1       =~ Float   # false
     1.0     =~ Float   # true
     1       =~ Integer # true
     1.0     =~ Integer # false
     /.*/    =~ Regexp  # true
     '.*'    =~ Regexp  # false
     true    =~ Boolean # true
     false   =~ Boolean # true
     'true'  =~ Boolean # false

The `Literal` type on its own is quite useful if you need to check that you have received
a single value as a parameter (i.e. not an array or hash or something more complex).

### Integer and Float Ranges

As you can see in the type hierarchy, the `Integer` and `Float` types can be parameterized
with an optional range *from* - `to`. 
This range is inclusive of the from/two values and it may be given
in the reverse order where from > to (it is still the same range). If to and from are equal
the range is a single value. It is also possible to use a literal `default` which in the first (from)
position means *-Infinity*, and *+Infinity* in the second (to) position. If only one value is given it
is taken to mean from the given value to *+Infinity*.

<? prettify language=rb?>

     1     =~ Integer[0,10]       # true
     -1    =~ Integer[0,10]       # false
     100   =~ Integer[0]          # true
     100   =~ Integer[0, default] # true

Float ranges work the same way, range values may be given as integers or float values.

<? prettify language=rb?>

     1.0     =~ Float[0,10]       # true
     -1.0    =~ Float[0,10]       # false
     100.0   =~ Float[0]          # true
     100.0   =~ Float[0, default] # true

### Iterating over Integer Range

An `Integer` range that is capped (i.e. not open ended at -Infinity or +Infinity) can be
used to iterate with any of the iterative functions. It behaves as if it were an array with
the values in order from from to to.

     Integer[1,10].each |$val| { notice $val }
     # notice 1
     # notice 2
     # ...
     # notice 10

For more details, see the respective iterative function how it works with respect to
getting the index as well as the value, and what it returns.

(And no, it is not supported to iterate over a `Float` range).

As you will see later, an `Integer` range is also very useful when it comes to describing
type constraints on a collection (array and hash) as it makes it easy to ensure that
a given array is not empty.

### String

A `String` unsurprisingly represents a text string. It can be parameterized with a *length range* 
that is specified the same way as the range parameters for an `Integer` range.

<? prettify language=rb?>

     'abc'   =~ String      # true
     'abc'   =~ String[1]   # true, it is >= 1 in length
     'abc'   =~ String[1,4] # true, it is between 1 and 4 in length
     ''      =~ String[1,4] # false
     'abcde' =~ String[1,4] # false, longer than 4
     
### Strings Matching Patterns / Enums

In the Puppet Type System, the types Pattern and Enum are subtypes of String. They are used to
describe strings with certain characteristics; those that match. In the case of Enum, matching
is done against one of its string values, and for Pattern, one of its regular expressions.

Let's start with Enum which is useful in situations where there are certain 'keywords', allowed
values - say used as keys in a hash.

     $colors = [blue, red, green, yellow, white, black]

     'blue'      =~ Enum[$colors]   # true
     'red'       =~ Enum[$colors]   # true
     'pink'      =~ Enum[$colors]   # false
     'deep-blue' =~ Enum[$colors]   # false
     
As you can see from the example above, the matching is strict, only strings that is
equal in value to one of the values listed in the Enum match.

The `Pattern` type in contrast matches against a regular expression. When constructing
a `Pattern` type, you can give it strings or regular expressions (mix as you like).

     $colors = [blue, red, green, /yellow/, /^white$/, black]

     'blue'       =~ Pattern[$colors]   # true
     'red'        =~ Pattern[$colors]   # true
     'pink'       =~ Pattern[$colors]   # false
     'deep-blue'  =~ Enum[$colors]      # true 
     'ocean-blue' =~ Enum[$colors]      # true
     'blueish'    =~ Enum[$colors]      # true
     'whiteish'   =~ Enum[$colors]      # false (the regexp was anchored with ^$)
     'sky-color'  =~ Enum[$colors]      # false (it is a type system, what did you expect)

### Regexp Type

The `Regexp` type represents a *Regular Expression*. It matches all regular expressions when not parameterized. It can also be parameterized with a regular expression in string or literal
regular expression form. When parameterized with a specific regular expression it works as
if it *was* a regular expression.

     /.*/       =~ Regexp           # true, it is a regular expression
     /.*/       =~ Regexp[/.*/]     # runtime error, left is not a string
     'blueish'  =~ Regexp['blue']   # true
     
This is mostly valuable since it allows constructing a regular expression using string
interpolation - i.e. you can do something like this:

     $prefix = 'http://myorg.com'
     $var =~ Regexp["${prefix}/index.html"]
     

### Strictness

The type system is strict; you cannot trick it into accepting strings containing digits
as being numeric, nor is an integer mistaken for a string. Empty strings are just that, a string
with length zero. Oh, and `undef` most certainly is undefined and not matching any of the other
types (unless you want to - but that is the topic of a later post).

### In the Next Post

In the next post I plan to cover the rest of the general types (the `Collection` types `Array` and 
`Hash`, `Data`, `Optional`, and `Variant`. And Oh, I *do* have to talk about `Undef` then. Maybe it becomes two posts...
