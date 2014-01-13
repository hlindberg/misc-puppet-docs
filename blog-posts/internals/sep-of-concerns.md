Puppet Internals - Separation of Concern
---

As we are getting closer to Puppet 4 where the future parser (available as an experimental feature since 3.2) and future evaluator (about to be released as an experimental feature in in 3.5) are
expected to become the standard, the implementation of these two (now experimental) features
is something that will be the concern of many contributors.

As the implementation in these new features is somewhat different from the rest of the Puppet
code base I want to explain the rationale behind the design, describe the various
techniques and how they are used in the future parser and evaluator.

So, in this series of posts about the implementation of Puppet's future parser/evaluator
I am going to be talking about concepts such as *polymorphic dispatch*, *adapters*, and *modeling*,
but also about more concrete things such as error handling.

Jumping ahead in the story - polymorphic dispatch and adapters are techniques that helps us
implement code in way that keeps different concerns separate. Before explaining how these techniques 
work it is important to understand what "keeping concerns separate" is all about, and what happens when there is no such separation.

### Separation of Concerns

Even the ancient Macedonians knew the importance of 'Separation of Concerns'. They phrased it differently though - King Philip II of Macedon, father of Alexander the Great, is attributed
to have coined the phrase 'Divide and conquer'. At that time (382-226 BC) they were naturally not 
dealing with maintenance of a large code base; 'divide and conquer' was the strategy the Macedonians 
used to deal with the Greek city-states they ruled over, and they had two goals in mind:

* break up top power alliances into smaller chunks to make them easier to subdue/manage
* prevent small power groups from linking up and becoming more powerful

This sounds like a perfect strategy for software! While we from a functional standpoint want
our logic to "link up" an "become more powerful" we certainly do not want to be subdued by
it from a maintenance and future development standpoint.
If you have worked with a long lived software project that has gone without a good trim for a long time you know what this looks like. Everything you want to change is interlinked with
everything else to the point that it is almost impossible to begin renovations without
causing the entire structure to collapse.

Certainly no one wants to create a system guided by the opposite principle; "lets mix it all up" - so
what causes software to almost secretly grow in complexity while no one was watching? Are there
evil elfs that cause this bit-rot?

Of source not, it typically
starts with one small step taken by one developer, added to by the next, and so on. This goes on
for a while, and then someone decides that there is too much duplication of code and code is
locally refactored. While there is now less code, there is also more cohesion. After a period
of increased cohesion there is usually a phase of feature expansion. Now this is more difficult
because of the cohesion and there is usually time pressures preventing a full scale refactoring.
Instead new functionality is shoehorned in. The system again undergoes refactoring and common
pieces are broken out into utilities for the sake of reusability (again less code and more cohesion).

What was once bad in terms of duplicated code (but easily changeable, because a variation
that was no longer needed could easily be deleted or changed) has been replaced by logic that almost everything depends on and no one dares to touch since consequences are very hard to predict. While
the practice of creating common reusable functionality in itself is a good thing, we typically
rush into it, under-design and too quickly let the use of our new shiny utility permeate the system.

It does not really matter which underlying technology something is implemented it - the problem
only manifests itself slightly differently depending on if it is object oriented, or functional,
if it is strongly typed or not. In general, the less stringent the implementation language is, the
more trouble you can get into, and faster.

### What is it we are separating?

What is it we are trying to separate anyway? Maybe you have heard that you should separate
"data" from "code". This does however not help us much as we always deal with some sort of data -
e.g. 1, 42, and "hello world" are all pieces of data. I like to think of these as being
*content* and *algorithms* - and what we like to separate, just like King Philip II did, is that any
part, be it content or algorithm, is broken up into manageable chunks. And by the way, content
is not always just data in the form of numbers, text, or structures thereof - our algorithms
could be of an higher order and juggle other algorithms (such as selecting which one out of
many algorithms to use, or composing a complex algorithm out of smaller independent ones).

### There once was a to_s

Even something simple as converting an object to string form is subject to the kinds of
problems "separation of concerns" warns us about. The first to implement a `to_s` on a class
clearly did so for a specific purpose - maybe it was for debugging, maybe to print out
information about the object in a report, maybe a label in a user interface, or something
that is included in an error message to help identify the location of a problem.
This list can become very long, there simply is no convention. Instead, there is typically a tendency
to implement multiple `to_s` - e.g. `to_label`, `to_debug_string`, `to_json`, `to_pson`, `to_yaml`, etc. etc.

While other functions we want to apply to a particular piece of data may not be
as generic as "represent in textual form" there are often several variations on how we want something
done. This may manifest itself as several similar methods or by having a rich set of parameters. Both
adding complexity to the implementation.

### Using a Strategy

What we want to do, instead of pushing every possible piece of wanted functionality into a
class, is to separate functionality into a separate piece of logic. This is often referred to
as using a "Strategy" or a "Policy" pattern. Depending on the language used such separation could
be achieved with inheritance, multiple inheritance, by using a "mixin", or aggregation. Of these only
aggregation (or indeed complete separation ) allows us to dynamically compose the behavior -
most languages only have features for static binding (even if it may be late binding at runtime).

The Ruby way of doing this is to write a module, and at runtime decide to include a specific module
into a class. This provides static late binding and we have to be careful that modules do not step on
each other since their methods are overlaid on top of what is already declared. Once included it is
hard to get rid of the logic, if we for some reason need to use different strategies at different
times (without restarting the runtime).

### Anemic Models

We want our content ("model", or "data" if you like) to be as simple as possible.
I often use the term *anemic* to describe the desired quality. A class that holds content
should only contain the intrinsic data, and the access-logic that protects its integrity.
The rest of the strategy / algorithm should be implemented separately.

Typically the behavior of data boils down to:

* Attribute accessors (a.k.a "getters" and "setters")
* Type safe setters (catch bad input early)
* Generic operations such as "equality" and "identity"
* Intrinsics such as "a car has four wheels", "a specific wheel can only be mounted on one car at 
  the time" (that is if we are implementing a Car object).


### Degrees of separation

Maybe it is enough to just not have all the code in one place and compose either statically at
"compile time", or selected dynamically at "run time". But what if we want to use different 
strategies all at the same time? (Just think about all the various ways we may want to
turn an object into "textual representation").

Sometimes there is good reasons to create a design with high cohesion and specialization - usually
to get performance out of the system. But as humans we are often dead wrong when we guess what
may be the bottlenecks of our system and it is best to optimize after measuring. A problem with
a design using tight coupling is that it is more difficult to change into a loosely coupled
design than vice versa, and it is also more difficult to test.

As a rule of thumb, design with anemic content model and use loosely coupled strategies.

### An Example

I am picking `ArithmeticExpression` as an example. Later in this series we will get to the details
of the real implementation, but the principle is the same.

An `ArithmeticExpresion` is used to represent an expression such as "1 + 2" in the Puppet
Programming Language. It has a left-expression (a '1' in the example), a right-expression ('2'),
and an operator (:'+'). It can be trivially implemented in Ruby as:

    class ArithmeticExpression
      attr_accessor left_expression
      attr_accessor right_expression
      attr_accessor operator
    end

Clearly this implementation does a poor job of protecting its integrity; the operator
can be anything, and so can the left and right expressions. We need to protect the setters
by changing the use of `attr_accessor` to `attr_reader` and write setters that validate their arguments. It is also inconvenient to create as we need to set the three attributes individually.
Apart from these problems it is a decent anemic design (in fact, it cannot really be more anemic
than this).

The problems come when we start adding `evaluate` and `to_s`. What is the purpose of the `to_s`?
The implementation below tries to recreate the source (which may be fine for something like
a simple arithmetic expression, but what about an if-then-else expression, or indeed the
top level construct containing all the expressions in a file, there we will need some sort of
formatting if the ambition is to be able to recreate the source in human readable form. Is it
really a good idea to implement this in one small piece per expression?

    class ArithmeticExpression
      attr_accessor left_expression
      attr_accessor right_expression
      attr_accessor operator
      
      def to_s
        "#{left_expr} #{operator} #{right_expression}
      end
      
      def evaluate
        left_expression.evaluate.send(operator, right_expression.evaluate)
      end

    end

The evaluate method also has problems. Clearly it must be given some kind of input
(a scope) to access variable values etc. but the real problem lies in that there is now
only one way an `ArithmeticExpression` can be evaluated. Its evaluation will be embedded into
other evaluations. What if we want to control which implementation to use at runtime? What if
we want to support the '+' operator on objects that do not implement this operation directly? How do we handle errors? What if we want to implement a debugger that allows us to step through the
evaluation? Also, `ArithmeticExpression` is only one out of a hundred or so expressions in the
Puppet Programming Language and breaking something like a debugger-concern into
pieces in hundred places is not particularly fun to implement and is costly to maintain. (We cannot simply inherit the behavior since it is intermixed with the particular evaluation of each expression
and its subexpressions).

While we could use language techniques such as inheritance to implement some common behavior
we then increase cohesion, and we still cannot modify the behavior dynamically. We could also
use a "inversion of control" (or injection pattern) and instantiate each expression
with strategies for producing a string and for evaluation.

    class ArithmeticExpression
      attr_accessor left_expression
      attr_accessor right_expression
      attr_accessor operator
      
      def initialize(label_provider, evaluator)
        @label_provider = label_provider
        @evaluator = @evaluator
      end
      
      def evaluate
        @evaluator.evaluate(self)
      end
      
      def to_s
        @label_provider.string(self)
      end
    end

Now, we have delegated the production of a textual representation and evaluation to
separate strategies and thus separated the concerns. We have however also
introduced bloat since each expression now needs to carry two additional
references, and we need to pass them to each constructor. We can make that better by providing
a default implementation that gets used if the caller did not give the implementation to use,
but that is more boiler plate code we need to write for each of the hundreds of expressions.
(And we have not even begun handling debugging, or more advanced formatting). While we did
handle the concerns via delegation, our ArithmeticExpression is still aware of these concerns -
it has to have methods for them; albeit small.
 
In this case, we really want a clean separation - the `ArithmeticExpression` simply should not
know how to represent itself in textual form, nor be able to evaluate itself. We want something
that is completely anemic to allow us to deal with the computational concerns more effectively.

Here is what the real implementation of `ArithmeticExpression` looks like. It is implemented
using `RGen`, a modeling framework that (among other things) ensures the integrity of the objects
(in this case that left and right are indeed Expressions, and that only supported operations
can be assigned).

    class BinaryExpression < Expression
      abstract
      contains_one_uni 'left_expr', Expression, :lowerBound => 1
      contains_one_uni 'right_expr', Expression, :lowerBound => 1
    end

    class ArithmeticExpression < BinaryExpression
      has_attr 'operator', RGen::MetamodelBuilder::DataTypes::Enum.new(
        [:'+', :'-', :'*', :'%', :'/', :'<<', :'>>' ]),
        :lowerBound => 1
    end

The use of RGen and modeling is a separate topic, but I will jump ahead a bit to enable
reading the above code; 

* `abstract` means that the class can not be instantiated (there are no
  pure `BinaryExpression` objects in the system, only objects of concrete subclasses such as   
  `ArithmeticExpression`).
* `'contains_one_uni'` means a containment reference to max one of the stated type
  * containment means that the referenced object may only be contained by one parent
    (compare to the example "a wheel of a car can only be mounted on one car at the time"),
  * 'uni' means that the reference is uni-directional; in general, an `Expression` does not know 
    about all the places where it may be contained.
* `:lowerBound=>1` declares that the value is required.
* An `Enum` data type allows one out of a set of given symbols to be assigned

As you probably noted, there is no `to_s` and no `evaluate` method. These are instead implemented
as separate strategies - e.g. there is an `Evaluator` class that has an `evaluate` method,
there is a `LabelProvider` strategy when we want a textual representation to be used as a label,
and yet another strategy for production of the text representation to use when performing
expression interpolation into strings. How these work will be covered in posts to come.

### Summary

In this post I have shown that it is desirable to separate concerns between content
and algorithms operating on content and that it is desirable to implement content
as anemic structures that only provides basic navigation of attributes and protection
of their own integrity.

### In the next Post

In the next post I will be covering the technique called *polymorphic dispatch* since it plays
an important role when implementing strategies.
