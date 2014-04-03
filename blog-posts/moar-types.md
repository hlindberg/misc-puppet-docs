Two Additions to the Type System
---

While working on ideas for a new API for Puppet Functions and Orchestration I found myself
wanting a couple of new types. Given a Puppet Labs Hack-Day, and some spare hours during the
weekend I am now happy to present two additions to the type system:

* `Struct` - a hash with specified keys and type per key
* `Tuple` - an array with specified sequence of types

These additional types will be available in the Puppet 3.5 release when using the --parser future
option.

### Struct Type

The `Struct` type fully specifies the content of a `Hash`. The type is parameterized
with a hash where the keys must be non empty strings, and the values must be types.

Here is an example, where the hash must contain the keys `mode` and `path`, and
`mode` must have a value that is one of the strings `"read"`, `"write"`, or `"update"`, and
the key `path` must have a `String` value that is at least 1 character in length.

    Struct[{mode=>Enum[read, write, update], path=>String[1]}]
    
A Struct type is compatible with a Hash type both ways, given that the constraints they
express are met. A `Struct` is a `Collection` (just like `Hash`), but its size is controlled
by the specified named entries. 

`Struct` supports optional values - this means that a matching hash may either have undef bound
to a key, or that the key is missing. A hash that has keys not specified in the `Struct` will
not match.

An unparameterized `Struct` matches all structs and all hashes.
    
### Tuple Type

The `Tuple` type fully specifies the content of an `Array`.
It is to `Array` what `Struct` is to `Hash`, with entries identified by their
position instead of by name. There is also some flexibility allowed with a variable
number of trailing entries.

    Tuple[T1, T2]                   # A tuple of exactly T1 and T2
    Tuple[T1, T2, 0]                # A tuple with a variable number of T2 (>= 0)
    Tuple[T1, T2, 1, 3]             # A tuple with a variable number of T2 (1-3 inclusive)
    Tuple[T1, 5, 5]                 # A tuple with exactly 5 T1
    Tuple[T1, 5, 10]                # A tuple 5 to 10 T1
    
All entries in the `Tuple` (except the optional trailing variable type size) must be a type
and denotes that there must be an occurrence of this type at this position. The tuple
can be modified such that the min and max occurrences of the last type in the type
sequence can be specified. The specification is made with one or two integer values or
the keyword `default`. The min/max works the same way as for an `Integer` range.
This way, if an optional last entry is wanted in the tuple, this is
entered as `Tuple[T, 0, 1]` (occurs 0 or 1 time). If the max is unspecified, it defaults to infinity
(which may also be spelled out with the keyword `default`).

     ["a", 1]     =~ Tuple[String, Integer]      # true
     ["a", 1,2,3] =~ Tuple[String, Integer, 1]   # true
     ["a", 1,2,3] =~ Tuple[String, Integer, 0]   # true
     ["a", 1,2,3] =~ Tuple[String, Integer, 0,2] # false
     ["a", 1,2,3] =~ Tuple[String, Integer, 4]   # false
     
The Tuple `type` is a subtype of Collection. Its size is specified by the given sequence
and the optional trailing occurrence specification of the last type.
     
### Summary

In this post you have seen the two new very useful types `Struct`, which fully
qualifies a `Hash`, and `Tuple` which fully qualifies an `Array`.

You find the start of the posts about the type system [here][1]

[1]:http://puppet-on-the-edge.blogspot.se/2013/12/what-type-of-type-are-you.html  