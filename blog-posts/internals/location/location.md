In post about Puppet Internals I am going to cover how source location is
handled by the lexer and parser. 

### Rationale for Detailed Position Information

It is important to have detailed position information when errors occur
as the user programming in the Puppet Programming Language would otherwise have
to guess about where in the source text the problem is.

To date, this output has consisted of file and line only. While this is enough in
many situations there are many cases where there is no reasonable text to output (say
using an operator like '+' the wrong way, and there are 5 '+' on the same line), just knowing
that there is something wrong with one of the '+' on line 3 is not that great. What we
want is to also know the position on the line.

### Implementation Background

In the 3x Puppet Language implementation, the positioning information was
limited to only contain the name of the file and the line number. In many cases
the information is wrong (or rather imprecise) as it relies on the positioned held in
the lexer as opposed to the position of the individual tokens. The lexer may have advanced
past the particular point where the problem is when the problem is reported.

The first implantation of the future parser (available in Puppet 3.2) contained
detailed positioning. It was calculated at the same time as the lexer did its
regular processing - i.e intermixed with producing the tokens that are fed to the
parser. 

This proved to be both complicated (as the lexer needs to look ahead and thus either maintain
a complex state where it is, what the location is etc.) and to be a performance hog. Part of
the performance problem is the need to compute the length of an entire expression to enable
future output of the corresponding source text.

The second implementation was much more performant. The idea was that detailed position
information is really only needed when there is an error and it could be computed lazily
if only recording the most basic information - i.e. the offset and length of the significant
parts of the source text. The complex state and intermixed position calculations could also
be made much more efficiently if done first, scanning the entire input for line breaks.

This implementation was introduced in the future parser in 3.4. Unfortunately, the idea
that positioning is really only needed when there is an error was wrong since the 3.4
implementation has to transform all parsed syntax tree into the 3.x AST equivalent tree, and
there all position information is still computed up front and stored inside each AST node (even
if never used).

Now, in Puppet 3.5, the new evaluator is responsible for evaluating most expressions
and it will only trigger the position computations when it is required; when there is
an error or when the expressions must be evaluated by the 3x evaluator (catalog operations
fall in this category).

While working on the performance of the lexer / parser it was also observed that it
would be beneficial to serialize the constructed syntax tree as deserialization of a
tree is much faster in general than again parsing the same source text. In order to be
able to support this, it was obvious that the detailed information needed to be included
in the model (and not only computed and kept in structures in memory).

### Requirements on Positioning Information

* Be fast to compute when parsing
* Serializable / De-serializeble
* Not be too expensive to compute when details are required
* Once computed it should continue to be available
* Provide file, line, and position on line
* Provide corresponding source text given an expression
* Handle source strings in UTF-8 (i.e. multibyte encoding)


### The Implementation in Puppet 3.5

A mix of techniques were used to meet the requirements.

The central concept is that of a Locator; an object that knows about the source text
string,where all the lines start, and given an offset into the string can answer which
line it is on, and its position on that line. This means that only the offset and length
of tokens needs to be recorded and stored in the syntax nodes.

We could store a reference to the Locator in every node, but that requires one extra
slot per node, and would need to be handled in de-serialization (i.e. setting thousands
of references when loading a single model). The offset and length are simply Integers and
are fast to serialize/de-serialize.

The parser always produces an instance of `Program`, and it contains both the source text
and the required line index. With these two, it can reconstruct the Locator (that was originally
created by the lexer / parser when parsing the source). The Program is only a data container,
it does not do any computation - that is always handled by an instance of Locator.

Here is a diagram that shows the relationship between the `Program` and the `Locator`. It also
shows how individual nodes (`Positioned`) and their corresponding computational / cache of
positioning (a `SourcePosAdapter`) relate to `Program` and `Locator`. Read on to learn how
those work.

PROGRAM_LOCATOR_DIAGRAM.PNG    
     
### Positioned

All nodes in the constructed syntax tree model inherit from `Positioned` (except `Program` which is 
always the entire source). Being `Positioned` means that there is an `offset` and a `length` (but nothing more).

If we want to know the line number and the position on the line we need to find the Locator
since it knows how to compute the information. We could have implemented that in the Positioned
object itself, but it would clutter its implementation and it would be difficult to change
the strategy for computing. This is where the SourcePosAdapter comes in.

### The SourcePosAdapter

Being an `Adapter` (there are others) means that it is bi-directionally associated with a particular object without the object knowing about it. The responsibility of the managing the relationship
is entirely on the adapter side.

An `Positioned` object is adapted to a `SourcePosAdapter` by:

    adapter = SourcePosAdapter.adapt(the_object)
    
The same instance of the adapter is always returned (it is created the first time). It is possible
to ask if an object is adapted (and get the adapter) by:

    adapter = SourcePosAdapter.get(the_object)
    
Once a `SourcePosAdapter` is obtained, it can answer all the questions about position. When it is
created it performs a minimum of computation. When asked for something that requires a `Locator`
is searches for the closest object that has knowledge of it and then caches this information. When
this takes place for the first time, the search always goes up to the `Program` (root) node. On subsequent searches a node with a `SourcePosAdapter` may be encountered and the search can stop
there. 

The resulting structure is what is depicted in the graph.

It is worth noting that all model objects that are contained, knows about their container via
the somewhat mysterious method `eContainer` (how that works in more detail and what
the difference is between a *containment*, and a *reference* is the topic for another blog post).

### Example

Say we have something simple like this:

     $a = 1 + 2 * 3

The lexer produces a sequence of tokens:

     VARIABLE, 'a', offset = 0,  length = 2
     EQUAL,    '=', offset = 3,  length = 1
     NUMBER,   '1', offset = 5,  length = 1
     PLUS,     '+', offset = 7,  length = 1
     NUMBER,   '2', offset = 9,  length = 1
     TIMES,    '*', offset = 11, length = 1
     NUMBER,   '3', offset = 13, length = 1
     
The `Parser` arranges them into a tree:

SYNTAXTREE.PNG

When the parser parsed the expressions, it did so by evaluation rules. Here is an excerpt
from the grammar.

    expression
      : ...
      | expression PLUS     expression   { result = val[0] + val[2]; loc result, val[1] }
      | expression MINUS    expression   { result = val[0] - val[2]; loc result, val[1] }
      | expression DIV      expression   { result = val[0] / val[2]; loc result, val[1] }
      | expression TIMES    expression   { result = val[0] * val[2]; loc result, val[1] }
      | ...

While there is much to talk about how the grammar / parser works, this post focuses on handling
of location, so the interesting part here are the calls to the `loc` method. It is called
with the resulting model node (e.g. an `ArithmeticExpression`) and then one or two other nodes
which may be model nodes or tokens produced by the lexer. All of the arithmetic expressions
are located by their operator (`lot` is called with `val[1]` which is a
reference to the operator i.e. '+', or '*' in the example).

Once the tree is built, since all of the nodes are `Positioned` it is possible to adapt them with a `SourcePosAdapter` to get the detailed computed information.

### Output

The output when there is position information is simply line:pos where pos starts from 1 (the first
character on the line).

Output of source excerpt is not yet implemented as it has its own challenges - some expressions
are quite long and span multiple lines, how much of that is relevant to show? How much is enough context? Also, while the data is in place, expressions like the arithmetic expressions are typically
located by their operator, and the output source would be just the '+'. A bit more processing is
needed to also include the left and right hand sides - but then again - how much of those.

As always the solution is probably to just show the line and a marker to where on the line the problem occurred.