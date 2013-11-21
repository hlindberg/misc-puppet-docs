Types, Values, and Variables
===
The Puppet Programming Language is a dynamically typed language, which means that the
type of values are not in general known until *runtime* (when the program logic is evaluated).

The Puppet Programming Language has a type system as well as operations on types.

The Kinds of Types and Values
---
There are two kinds of types in the Puppet Programming Language; *Puppet Types*, and the types of
the underlying runtime "platform" language - the *Platform Types*. There is also a special Puppet Type called *Undef*.

## Platform Types

At present, the only existing implementation of the
Puppet Language is written in Ruby, but there may be other implementations in the future. In general,
the ability to refer to platform types is to allow configuration of a runtime, handle
references to concepts such as plugins. **Regular Programs in the Puppet Programming Language
do not make use of the platform types**.

A Platform type is named after the runtime; currently only `Ruby`. It is a *Parameterized Type* where
the type parameter is a reference to the *type name in the platforms type system* encoded as a Puppet String.

<table><tr><th>Note</th></tr>
<tr><td>
  The platform type names <code>Jvm</code>, <code>C</code>, and <code>Go</code> are reserved
  for potential future use.
</td></tr>
</table>

As an example, if there is a puppet extension written in Ruby with the name `Puppetx::MyModule::MyClass`, the platform type is `Ruby['Puppetx::MyModule::MyClass']`.

## The Undef Type
There is a special undefined/null/nil type - called `Undef`; the type of the expression `undef`.
Values of the `Undef` type can always undergo a widening reference conversion to any other type. The reverse is however not true; only the value `undef` has the type `Undef`.

A value of `Undef` type is assignable to any other type with the meaning *without value*.

<table><tr><th>Note</th></tr>
<tr><td>
  In practice the programmer can ignore the existence of the `Undef` type and pretend that
  `undef` can be of any type.
</td></tr>
</table>

## Puppet Types

Puppet Types include the types that are meaningful in a Puppet Program - these are divided into
*Data Types* (e.g. `Integer`, `String`, and `Array`), *Catalog Types* (e.g. `Resource`, `Class`), and *Abstract Types* (e.g. `Collection`; the parent type of `Array` and `Hash`, `Literal`; the parent type of all literal data types (`Integer`, `Float`, `String`, `Boolean`),
`CatalogEntry`; the parent type of all types that are included in a *Puppet Catalog*, and the type `Data`; a parent type of all kinds of general purpose "data" (`Literal` and `Array` of `Data`, and `Hash` with `Literal` key and `Data` values).

All types (Platform and Puppet) are organized into one *Type System*.

The Type System
===============

The type system contains both concrete types; `Integer`, `Float`, `Boolean`, `String`, `Pattern` (regular expression pattern),
`Array`, `Hash`, and `Ruby` (represents a type in the Ruby type system - i.e. a Class), as well as abstract
types `Literal`, `Data`, `Collection`, and `Object`. 

The `Array` and `Hash` types are parameterized, `Array[V]`, and `Hash[K,V]`, where if `K` is omitted, it defaults to `Literal`, and if `V` is omitted, it defaults to `Data`.

The Integer type is also parameterized to enable integer range as a type. By default, an Integer
represents all integral number +/- infinity. (See Integer for more information).

The `Ruby` type (i.e. representing a Ruby class not represented by any of the other types) does not have much
value in puppet manifests but is valuable when describing bindings of puppet extensions.
The Ruby type is parameterized with a string denoting the class name - i.e. `Ruby['Puppet::Bindings']` is a valid type.

The abstract types are:

- `Literal` - `Integer`, `Float`, `Boolean`, `String`, `Pattern`
- `Data` - any `Literal`, `Array[Data]`, or `Hash[Literal, Data]`
- `Collection` - any `Array` or `Hash`
- `Object` - any type

The type hierarchy is shown in the figure below. (A single capital letter denotes a 
reference to a type, lower case type parameters have special processing rules as shown
in section specific to each type). Note that parameterized type may be referenced
without any parameters, in which case type specific rules apply. Also note that the same type
may appear more than once in the hierarchy, typically with different narrower type parameters.

     Object
       |- Ruby[class_name]
       |- Undef
       |- Data
       |  |- Literal
       |  |- Array[Data]
       |  |- Hash[Literal, Data]
       |
       |- Collection
       |  |- Array[T]
       |  |- Hash[K, V]
       |
       |- Literal
       |  |- Numeric
       |  |  |- Integer[from, to]
       |  |  |  |- (Integer with range inside another Integer)
       |  |  |- Float
       |  |- String
       |  |- Boolean
       |  |- Pattern[pattern_string]
       |
       |- CatalogEntry
       |  |- Resource[type_name, title]
       |  |- Class[class_name]
       |  |- Node[node_name]
       |  |- Stage[stage_name]
       |
       |- Type[T]
       |

In addition to these types, a Qualified Reference that does not represent any of the other types is interpreted as `Resource[the_qualified_ref]` (e.g. `File` is shorthand notation for `Resource[File]`).
          
          
TODO: (Node, and Stage are not yet implemented. Ruby and Type are reserved but not functional)

Runtime Types
---

An implementation of the Puppet Language is allowed to make efficient use of the underlying
runtime and may choose to represent instances of puppet types using
instances of types
in the platform language's type system. In these cases, it is allowed to map these types
directly to the puppet type system.

As an example, the Ruby implementation of the Puppet Programming Language uses the Ruby classes `String`, `Integer` (`Fixnum`, `Bignum`, etc), `Float`, `Hash`, `Array`, `Regexp`, `TrueClass`, `FalseClass`, `NilObj`. Instances of these Ruby types are directly mapped to the corresponding puppet types (e.g. even if an instance of a puppet `String` is an instance of the Ruby class called `String`, it is not interpreted as `Ruby[String]`.

### Ruby[T]

Represents a type in the platform's type system. The type parameter T may not be omitted and
must be of `String` type and contain a valid string representation of the Ruby type. The referenced type does not have to exist; it is still a reference to a type (albeit a currently not existing type). The type must exist when operations are performed on the type (i.e. must be loadable).

### Object

Represents the abstract type "any".

### Undef

Represents the notion of "missing value". 
`Undef` is the type of the expression `undef`.

Values of the `Undef` type can always undergo a widening reference conversion to any other type. The reverse is however not true; only the value `undef` has the type `Undef`.

### Data

Represents the abstract notion of "data", its subtypes are `Literal`, and `Array[Data]` or
`Hash[Literal, Data]`.

### Literal

Represents the abstract notion of "value", its subtypes are `Numeric`, `String`, `Boolean`, and
`Pattern`.

### Numeric

Represents the abstract notion of "number", its subtypes are `Integer`, and `Float`.

### Integer ([from, to])

Represents a range of integral numeric value. The default is the range +/- infinity.

There is no theoretical limit to the smallest or largest number that can be represented
as an implementation should transparently represent the value as either a 32 or 64 bit
machine word, or as a *bignum*. There is a practical limit; while a bignum can grow to
infinite size, computer scientist has yet to invent a computer with infinite amounts of
memory.

The Integer type can optionally be parameterized with `from`, `to` values to provide a range.
The range can be *ascending* or *descending*. (The direction is only important when iterating
over the set of instances).

If `from` is unassigned, the default is -infinity, and if `to` is unassigned, the default is +infinity.
From the Puppet Language, the default values are set by using a `LiteralDefault`. If only one
parameter is given, it is taken as both `from` and `to`, (thus producing a range of one value).
The `from` and `to` are inclusive.

Examples:

     Integer[0, default]   # All positive (or 0) integers
     Integer[1, default]   # All positive integers
     Integer[default, 0]   # All negative (or 0) integers
     Integer[default, -1]  # All negative integers

When performing tests in the Puppet Programming Language, a range inside of another is
considered to be less than the wider range (i.e. a subset of). They are equal if, and only
if the lower and upper bounds are equal.

     Integer[1,10] > Integer[2,3]   # => true
     Integer[1,10] == Integer[2,3]  # => false (they are not equal)
     Integer[1,10] > Integer[0,5]   # => false (overlap)
     Integer[1,10] > Integer[1,10]  # => false (not a subset, they are equal)
     Integer[1,10] >= Integer[1,10] # => true (they are equal)
     Integer[1,10] == Integer[1,10] # => true (they are equal)
     
Testing value against range:

     $value =~ Integer[1,10]
     
     $value ? { Integer[1,10] => true }

     case $value {
       Integer[1,10] : { true }
     }
          
Iterating over an integer range:

     Integer[1,5].each |$x| { notice $x } # => notices 1,2,3,4,5
     Integer[5,1].each |$x| { notice $x } # => notices 5,4,3,2,1
     
     Integer[0,default].each |$x| { notice $x } # error, unbound range (infinite)

### Float

Represents an *inexact* real number using the native architecture's double precision floating
point representation.

Learn more about floating point than you ever want to know from these articles:

* docs.sun.com/source/806-3568/ncg_goldberg.html
* wiki.github.com/rdp/ruby_tutorials_core/ruby-talk-faq#wiki-floats_imprecise
* en.wikipedia.org/wiki/Floating_point#Accuracy_problems

### String

Represents a sequence of Unicode characters up to a maximum length of 2^31-1 (the maximum
non negative 32 bit value).

### Boolean

The types of the boolean expressions `true` and `false`.

### Pattern[pattern_string]

The type of a Regular Expression produced by the following Puppet Language constructs:

     LiteralRegularExpression
       : '/' RegexpString '/'
       | 'Pattern' '[' SExpression ']'
       ;

     Expression
       : . . .
       | Expression '=~' (SExpression | LiteralRegularExpression)
       | Expression '!~' (SExpression | LiteralRegularExpression)
       ;
       
Where `SExpression` is an expression that evaluates to `RegexpString` (a string containing a valid
regular expression), and `Expression` evaluates to a regular `String` (only strings can be matched
by a regular expression. The RHS of the `=~`, `!~` operators accepts an `SExpression` or a `LiteralRegularExpression`; if a string is given a new regular expression is created from this string.

The syntax of the Regular Expression is defined by Ruby's implementation. Puppet's regular
expressions does not support `\A` and `\Z` and does not support options. If `\A` or `\Z` are used
in the regular expression string, these are removed. If an attempt is used to specify options,
this will result in an error (e.g. `/.*/m`).

The result of `Pattern[regexp_string]` is an instance of the type, not a specialization of
the type.

### Array[V]

Array represents an ordered collection of elements of type V. The first index is 0.
The index into an array is a non negative Integer. (Operations in the Puppet Language
allows negative values to be used to perform different calculations w.r.t index). See
Array [] operation (TODO: REFERENCE TO THIS EXPRESSION SPEC).

The type of V is unrestricted.

### Hash[K, V]

Hash represents an unordered collection of associations between a key (of K type), and
a value (of V type).

The types of K and V are unrestricted.

TODO: The key may be restricted.

### Catalog Entry

Represents the abstract notion of "something that is an entry in a puppet catalog". Its
subtypes are `Resource`, `Class`, `Node`, and `Stage`.

### Resource[type_name, *title]

Represents a Puppet Resource (a resource managed by Puppet).

The Resource type is parameterized by `type_name`, and optionally `title`(s).

* The `type_name` parameter can be an `Expression` evaluating to a `Resource` type, or a `String`
  containing the name of the resource type (case insensitive).

* The title type parameter is optional and multi valued. Each title is an `Expression` evaluating
  to a `String` representing the title of a resource.
  
* If no title is given, the result is a reference to the type itself; e.g. `Resource[File]`, 
  `Resource['file']`, `Resource[file]` are all references to the puppet resource type called File.
  
* When a single title is given, the result is a reference to the singleton instance of the
  resource uniquely identified by the title string.
  
* When multiple titles are given, the result is an `Array[Resource[T]]`; e.g.
  `Resource[File, 'a', 'b']`  produces the array `[Resource[File, 'a'], Resource[File, 'b']]`.
  
#### Shorthand Notation

Any QualifiedReference that does not reference a known type is interpreted as a reference
to a Resource type. Thus `Resource[File]` and `File` are equivalent references.

The shorthand notated resource types supports type parameterization with title(s). These
are equivalent: `Resource[File, 'a', 'b']`, `File['a', 'b']`, they both produce an equivalent
array of two references - `File['a']` and `File['b']`.

#### Type Algebra on Resource

    Resource <= Resource[RT] <= Resource[RT, T]
    Resource[RT1] != Resource[RT2]
    Resource[RT, T] != Resource[RT, T2]
    Resource[RT] == RT
    Resource[RT, T] == RT[T]
    
    Resource        ∩  Resource         → Resource
    Resource[RT]    ∩  Resource[RT]     → Resource[RT]
    Resource[RT1]   ∩  Resource[RT2]    → Resource
    Resource[RT,T]  ∩  Resource[RT, T]  → Resource[RT, T]
    Resource[RT,T1] ∩  Resource[RT, T2] → Resource[RT]
    
### Class[*class_name]

Represents a Puppet (Host) Class. The `Class` type is parameterized with the name of
the class (`String`, or `QualifiedName`).

If multiple class names are given, an `Array` of parameterized `Class` types is produced.

### Class Inheritance - TODO

The type system does currently not treat (Host) Class inheritance as subtyping.
The reason for this is that if the type system were to do this, then classes need to be loaded in order for type operations to correctly answer if a class inherits another. There was a suspicion
that this may affect the result (logic may reference a class that should not be loaded because
it is used as a condition to load classes that are not present). 

Further work is needed to make a final decision. If the decision is made to keep it the way
it is currently implemented, the user logic will need to check twice (is it the subclass or
the superclass; this since Puppet only supports one level deep inheritance.

#### Type Algebra on Class

    Class <= Class[c]
    Class       ∩  Class        → Class
    Class[c]    ∩  Class[c]     → Class[c]
    Class[c1]   ∩  Class[c2]    → Class
 

### Node - TODO

The Node type represents a Puppet Node. This type is not yet implemented.

### Stage - TODO

The Stage type represents a Puppet Stage. This type is not yet implemented. 

### Type[T]

Type is the type of types. It is parameterized by the type e.g the type of `String` is `Type[String]`.

Operations per Type
---
The operations available per type is specified in the section TODO REF TO OPERATORS DOCUMENT.

Variables
---
A variable is a storage container for a value. Variables are immutable (once assigned they cannot be assigned to another value, and the value it is referring to is also immutable.

The type of a variable is determined by what is assigned to it.

<table>
<tr><th>Note</th></tr>
<tr><td>  
  In the current implementation all parameters imply that they are of <code>Object</code> type (and 
  anything can be passed). User logic is responsible for asserting type.
</td></tr><tr><th>Future</th></tr>
<tr><td>
  In the future it will be possible to specify the type of parameters to classes,
  resource type definitions, and lambdas. Possibly also the attributes of resource types.
  When that is added to the language the system will 
  ensure that the given value is type compliant with the specified type.  
</td></tr>
</table>

### Initial Values of Variables

A Puppet Programming Language Variable comes into existence when an assignment is made to
the variable. There is no such thing as an un-initialized variable since all variables that
exist have a value (even if that value may be the literal `undef` value).

Conversions and Promotions
===
The Puppet Programming Language is in general dynamically typed (everything is an Object unless declared otherwise). There are various operators that perform type coercion / transformation
if required and when possible, there are functions that perform explicit type conversion,
and there are typed parameters that will perform type conversion when required and possible.

The exact conversions are documented per language feature. This section describes the general
conversions and promotions.

Numeric Conversions
---
* When arithmetic operations are done on `Numeric` types - if one or both operands
  are of `Float` type, the result is also of `Float` type.
  
* There are never any under or overflow when performing Integer arithmetic. The implementation
  handles automatic conversion from 32 to 64 bit numbers to bignum.
  
String to Numeric Conversion
---

* Arithmetic operations are done on Numeric types - if an operand is a String an attempt is made
  to transform it into numeric form (rather than giving up immediately).

* String to Number conversion also takes place for typed parameter assignment. (TODO: typed parameters is not yet implemented).

* Numbers are not generally transformed to Strings (since this requires knowledge of
  radix). They are transformed using radix 10 when interpolated into a String.
  
* Explicit conversion from Number to String is performed by calling the `sprintf` function.

* Interpolation of non String values into a string uses default conversion to String.

Boolean Conversion
---
Puppet has a sense of Boolean "truth" and will convert values to Boolean as shown below:

     ''    → false
     undef → false
     false → false
     any other → true

String to Regexp Conversion
---
If the RHS operand of a match expression evaluates to a String, the string is converted into a regular expression.

Qualified Name and Qualified Reference to String
---
Qualified Names evaluate to String type unless the name appears in an expression that uses
the name as a reference to an instance (e.g. the name of a function in a function call).

The reverse is not generally true; a String value can not always be used where a Qualified Name is
allowed (e.g. `$'x'` is not a valid reference to the variable named `'x'`).

Qualified Reference to String
---
Qualified References are only converted to String when interpolated into a String expression.

