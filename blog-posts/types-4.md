In the [previous post][1] about the Puppet 3.5 experimental feature Puppet Types I covered
how the type system handle undefined values and empty constructs. Earlier posts in this series presents the rationale for the the type system, and an overview of the fundamental types.

This time, I am going to talk about the remaining general types; the very useful
`Variant` and `Data` types as well as the more esoteric `Type` type.
I will also explain the `Ruby` type, the rationale and how it is used in the type system.

[1]:http://puppet-on-the-edge.blogspot.se/2013/12/lets-talk-about-undef.html

### The Variant Type

Let's say you want to check if values in a hash are either one of the words "none" or "all", or
is an array of strings. This is easily done with a Variant:

    $my_structure =~ Hash[Variant[Enum[none, all], Array[String]]]

The `Variant` type considers instances of one of it's types as being an instance of the variant. An
unparameterized Variant matches nothing.

Accept either an array of strings, or an array of numeric (i.e. mixing numeric and strings in
the same array is not allowed):

    Variant[Array[String], Array[Numeric]]
     
Accept a symbolically named color, or a RGB integer value (0 to 0xFFFFFF):

    $colors = [foreground, background, highlight]
    Variant[Enum[$colors], Integer[0, 0xFFFFFF]]

### Variant and Optionality / Undef

If you want to make the variant optional, you can add `Undef` as a type parameter (i.e. there
is no need to wrap the constructed variant type in an `Optional` type). In fact, `Optional[T]` is
really a shorthand for `Variant[T, Undef]`.

### The type called Data

The `Data` type is a convenience type that represents the sane subset of the type system that
deals with the regular types that are meaningful in the Puppet Programming Language. Behind the
scenes `Data` is really a `Variant` with the following definition:

    Variant[Undef, Literal, Array[Data, 0], Hash[Literal, Data, 0]]
    
This means that `Data` accepts `Undef`, any `Literal`, and nested arrays and hashes where arrays and hashes may be empty or contain `undef`. A hash entry may however not have an `undef` key.

### Default in Array and Hash

The `Data` type is the default type of values in an `Array` or `Hash` when they are not
parameterized, such that:

    Array == Array[Data]         # true
    Hash  == Hash[Data]          # true
    Hash  == Hash[Literal, Data] # true
    
### Data vs. Object

If you are tempted to use `Object` to mean "any" you must be prepared to also handle the types
Ruby, all of the `CatalogType` sub types (`Class`, `Resource` and its subtypes), the `Type` type, and the `Ruby` type, and possible future extensions to the type system for other runtime platforms than Ruby.

While the above mentioned types can be serialized in string form and parsed back to a type representation they can not be directly represented in most serialization formats.

### The Type Type

Since all the various values that are being used have a type, and we allow types themselves to
be used as values; assign them to variables etc. we must also have a type that describes that
the value is in fact a type. Unsurprisingly this type is called `Type`, and it is parameterized
with the type it describes. This sounds more confusing than what it is -  and is best illustrated with an example:

    Integer =~ Type[Integer]  # true

The next question is naturally what the type of `Type` is - and you probably guessed right;
it is also `Type` (parameterized with yet another `Type`). And naturally, for each step we take towards "type of", it gets wrapped in yet another `Type`.

    Type[Integer] =~  Type[Type[Integer]] # true
    
And this does indeed go on to Infinity.
While this can be solved in various ways by "short circuiting"
and erasing information, there is really very little practical need for such a solution. We could state that the type of `Type[Integer]` is `Type[Type]`, or one level above that by making the type of `Type[Type[Integer]]` be `Type[Type]`. We could also introduce a different abstraction like `Kind`, maybe having subtypes like `ParameterizedType`, `FirstOrderType`, `HigherOrderType` and so on. This however have very little practical value in the Puppet Programming
Language since it is not a system in which one solves interesting type theory problems. There simply
are no constructs in the language that would allow making any practical use of these higher order types.

With that small excursion into type theory, there actually *is* practical value in being able
to reason about the type of a type. As an example, we can write a function where we expect the user
to pass in a type reference, and we want to validate that we got the right ehrm... type. Let's say
the function does something with numbers and you are willing to accept an `Array` of `Integer` and `Float` ranges, which is illustrated by this expression:

    [Integer[1,2], Float[1.0, 2.0]] =~ Array[Type[Numeric]]  # true

This is about how far it is of practical value to go down this path. The rest is left as a paradox
like the classic, "Is there a barber that shaves every man that does not shave himself?".

### The Ruby Type

The type Ruby is used to represent a runtime system type. It exists in the type system primarily
to handle configuration of the Puppet Runtime where it is desirable to be able to plugin
behavior written in Ruby. When doing so, there must be a way to reference Ruby classes in a
manner that can be expressed in ways other than Ruby itself. The type system has the ability
to describe a type in string form, and parse it back again.

The Ruby type also serves as a "catch all", just in case someone writes extensions for Puppet
and returns objects that are instances of types that the Puppet Programming Language was
not designed to handle. What should the system do in this case? We don't want it to blow up
so something sensible has to be returned - for no other reason than to be able to print out
an error message with reasonable information about the alien type.

There are also experiments being made with making configuration of the Puppet runtime
in the Puppet Programming Language - but that is the topic of another series of blog posts.

While you can create a Ruby type in the Puppet Programming Language, there are currently no functions 
that operate on those - so they have very limited practical value at the moment. If you however
write your own custom functions there is support in Ruby to use the Ruby type, instantiate
a class etc.

In the Puppet Programming Language, a Ruby type is parameterized with a string containing
the fully qualified name of the Ruby class.

    Ruby['MyModule::MyClass']

### In the Next Post

With the adventure into "what is the type of all types" in this post, I am going to return
to what the type system is really all about; supporting the types that end up in the catalog; `Class` and `Resource`.