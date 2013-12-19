What Type of Type are You
===
In the upcoming Puppet 3.5.0 the experimental Type System (first introduced into the code base
in Puppet 3.3.0 (also experimental)) has been put to good use in the "future parser". In this
post I will show some of the things that the type system can do to help you increase the
quality of your Puppet logic. This is also an introduction to the concept of Types. I will come
back with more posts about additional types, and how they can be used in various Puppet expressions.

But all series must have a beginning...

What is a Type System?
---
At first when mentioning "types", you may start to feel nauseous thinking about statically typed
programming languages littered with superfluous type declaration. This kind of "your grandfather's
typing" is not at all what the new type system is about - like this horrible piece from C.

    char *(*(**foo[][8])())[]; // huh ?????


> In programming languages, a type system is a collection of rules that assign a property called a type to the various constructs—such as variables, expressions, functions or modules — a computer program is composed of. The main purpose of a type system is to reduce bugs in computer programs by defining interfaces between different parts of a computer program, and then checking that the parts have been connected in a consistent way. This checking can happen statically (at compile time), dynamically (at run time), or as a combination thereof.
> -- <cite>[Wikipedia] [1]</cite>

[1]:http://en.wikipedia.org/wiki/Type_system

 
Don't worry - Puppet is a dynamically typed language and will remain so. The new Type
system is there to help you with certain tasks. It is not a straight jacket designed to help
a static compiler.
     
You are already using types
---
Whenever you are using Puppet match expression to check if a String has a particular pattern
you are actually using typing! With a bit of type jargon, we can say that what you are doing is checking if you particular string is an instance of a subtype of String - one out of many that also matches the pattern.

     $my_string =~ /(blue)|(red)|(green)/
     
A type system is just that, a pattern system that is applied to certain properties of
the objects it operates on. What the example does is that it matches all kind of red, green,
blue strings - e.g. 'rose red', 'deep red', 'dark blue', 'viridian green'. In other words
we have written a statement that checks "Is this string the type of string that has a color
word in it?".

In Puppet 3.5's future parser we can take this a step further and name the pattern.

    $primary_color_string = /(blue)|(red)|(green)/

    $my_string =~ $primary_color_string
    
And look, we almost (kind of) created a Type.

The Rationale for Types
---
Regular expression are great, but they cannot help us with everything we need to check. They
can only be used with strings for example, and if we need to check a structure of some sort
(say an array, or a hash) it starts to become difficult - we need to iterate, we may need to
call functions and the task we tried to achieve starts to be overshadowed by general programming
logic.

Let's say we want to check that an Array of values are all integers within a given range. The first
problem in Puppet 3x is that all numbers are string values, and users may write them in decimal,
hex or octal, so you have to write regular expressions that can handle all of those (but lets
skip that painful part of the problem). We do have the comparison operators <, > etc. that work
on numbers. However, since there is no iteration in 3.x we cannot loop over
the array, and we do not know how many elements there are so we cannot hardcode the checks (first 
check entry 0, then 1, and so on). The path with least extra work is to write a custom function in ruby (or find something on the forge that suits our needs).

    # hard-coded
    $my_array[0] >= 0 and $my_array[1] <= 10
    $my_array[1] ... # this is getting old quickly
    # give up...
    
With the future parser we can at least iterate:

    $my_array.each |$element| { $element >= 0 and $element <= 10 }
    
Which is much better naturally, but still noisy.

Example - an Array of Integers in a Range
---
Lets jump forward a bit. One of the types in the new type system is `Integer`, and it can be parameterized to describe a range. (A parameterized type is just like a more specific pattern -
it narrows down the number of objects it matches. A parameter is typically another type,
but can be something concrete like numbers in a range).

Another type is `Array`, which can also be parameterized with another type - the type of
its elements. Parameters to a type is written in brackets after the type.
We can put this to use in Puppet 3.5's future parser since the match operator now also matches based on type.

    $my_array = [1, 2, 3, 11]
    $my_array =~ Array                 # true, it is an array
    $my_array ≈~ Array[Integer]        # true, it is an array, and all elements are integers
    $my_array =~ Array[Integer[0,100]] # true, all values are in the range 1-100
    $my_array =~ Array[Integer[0,10]]  # false, one value, 11, is not <= 10
    
Type Hierarchy
---
If you have done a bit of programming in other languages you already know that types (or Classes
as they are typically called) follow a hierarchy. This is also true in the Puppet Type System.

As an example, all strings that match `/(blue)|(red)|(green)/`, also match `/(lu)|(red)|(een)/`, but
not vice versa - we can say that those that match the more restrictive pattern 'colors' are also 'lu-red-eens', or that 'colors' is a sub-type of 'luredeens'.

We do the same with Types. A `Number` (just like 'luredeen') is an abstract type, and it has
two sub-types; `Integer` and `Float`.

     $my_array [1, 2, 3.1415]
     $my_array =~ Array[Integer]   # nope, there is a float in there
     $my_array =~ Array[Float]     # nope, there are integers in there
     $my_array =~ Array[Number]    # yep, they are all numbers
     
Typically this is shown as a hierarchy:

     Number
       +- Integer
       +- Float
       
Let's throw in a Sting in the mix as well:

     $my_array [1, 2, 3.1415, "hello"]
     $my_array =~ Array[Integer]   # nope, there is a float and a string in there
     $my_array =~ Array[Float]     # nope, there are integers and a string in there
     $my_array =~ Array[Number]    # no, there is a string in there
     ?                             # then what?
     
To deal with this, the Type system has additional abstract types - `Literal` which describes
something that has a single value, and `Object`, the most abstract "anything" (there are more
abstract types which I will come back to). Here is the updated hierarchy:

    Object
      +-Literal
        +- String
        +- Number
           +- Integer
           +- Float

And now we can check:

    $my_array =~ Array[Literal]   # true
    $my_array =~ Array[Object]    # true
    $my_array =~ Object           # true
    
So what good does checking against Object do you may ask. Well, not much except it is clear
that something that accepts `Object` is prepared to handle anything. It is also useful
when there are error messages that print out the type - if you can something like
"*type mismatch, an Array[Object] cannot be used where an Array[Integer] is expected*", you know that
the problem is that there is "other stuff" in that array. 

In the Next Post
---
There are several other types to talk about; there are the literals `Boolean`, and `Regexp`, the 
abstract `Collection` with subtypes `Array` and `Hash`, types that deal with enumeration; `Pattern` 
and `Enum`, a type that allows different types called `Variant`, as well as puppet specific types such as `Resource`, `Class`, `File`, etc.
 