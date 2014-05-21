In this series of blog posts about the future parser/evaluator the turn has come to
*polymorphic dispatch*, a technique used to implement a *strategy pattern* where
the logic is kept separate from the data/content it is operating on. The rationale for this
is described in the previous post on ["Separation of Concerns"][0].

[0]:http://puppet-on-the-edge.blogspot.be/2014/01/puppet-internals-separation-of-concerns.html

### The Basic Problem

The basic problem when implementing a [Strategy][1] pattern is that we essentially want to
write strategy methods as if they were part of the classes it operates on. In Ruby this
is easily done (if we can accept static late binding) since we can:

[1]:http://en.wikipedia.org/wiki/Strategy_pattern

* include a module in a class
* reopened a class and add/modify methods 

We can however not easily support several variants of the same strategy, and we have to make
sure that what we apply does not introduce methods with the same name since they would override
each other's contributions to the class otherwise. 

Essentially, dynamically adding/modifying a class' behavior is [Monkey Patching][2], which should be 
reserved as a last resort to temporarily fix problems in 3d party logic.

[2]:http://en.wikipedia.org/wiki/Monkey_patch

### Polymorphic Dispatch

In the Puppet 3.x future parser/evaluator, polymorphic dispatch is implemented using a [Visitor Pattern][3] and I am going to jump straight into examples showing how this implementation is used.

[3]:http://en.wikipedia.org/wiki/Visitor_pattern

### A Simple Label Provider

Let's say we want to implement a `LabelProvider` strategy that produces a string that describes what something *is* and that is suitable for inclusion in an error message. The typical alternative
would be to just output the name of the class - while clear to implementors, users will however
have a hard time understanding references to implementation classes.

There are several options available when using a visitor and we are going to start with
the simplest form of visitor and add an implementation that just outputs "Object (label provider is incomplete)" for all kinds of objects.

    class LabelProvider
    
      def initialize
        @label_visitor = Puppet::Pops::Visitor.new(self, "label")
      end
      
      def label(o)
        @label_visitor.visit(o)
      end
    
      protected
      
      def label_Object(o)
        "Object (label provider is incomplete)"
      end
    end
    
In this example, we created a `Visitor` that is configured to dispatch calls to `self`, and to make
calls to methods that start with `"label"` followed by an underscore, and the last part
of the class name of the object it is told to operate on. If no such method is implemented,
a search is made up the class hierarchy of the given object until a method is found. If no method
is found an error is raised.

We then use the label provider to produce output:

    provider = LabelProvider.new
    puts provider.label(3)

We can now add methods as needed to create labels for all kinds of objects.

    def label_ArithmeticExpression(o)
      "#{o.operator} Expression"   # i.e. '+ Expression', '- Expression' etc.
    end
    
    def label_Regexp(o)
      "Regular Expression"
    end

I typically use the letter 'o' for the argument to mean 'the visited object' (which is guaranteed
to be an instance of the class) as it requires less effort to identify the visited object in the
logic if it has the same name in all of the polymorphic methods.

### A more Efficient Label Provider

While the simple label provider in the previous example does the job perfectly well it is also
the slowest. Each time we need a label provider, the visitor needs to be recreated and we are
not fully benefiting from its ability to cache the resolution from visited object to called method
as this cache is lost when the label provider goes out of scope. We can change that by making
the visitor a class instance variable. When doing this we also need to modify how the call
is made. Here is the improved implementation:

    class LabelProvider
    
      def initialize
        @@label_visitor ||= Puppet::Pops::Visitor.new(self, "label")
      end
      
      def label(o)
        @@label_visitor.visit_this(self, o)
      end

    # the rest is the same...
    end
    
We can make one further optimization; since the visitor can be used with any number of
arguments, the generic form of calling `visit` (or `visit_this`) accepts a variable number of
arguments, and requires some internal shuffling of the arguments. We can instead call an optimized version (~30% faster) - in this case `visit_this_0`, (it is '0' since we are not giving any additional arguments (except the visited object)).

      def label(o)
        @string_visitor.visit_this_0(self, o)
      end

There are optimized versions for 1, 2 or 3 arguments, called `visit_this_1`, etc.

The optimized (caching) version can be used when we know that the class hierarchy or the set of available visitable methods is not going to change. If that is the case, we would need the use the non caching variant.
(As a side note, if we are dealing with a design where classes are redefined
to be subclasses of something other than their current superclass we are really in trouble).

### Min and Max number of arguments

By default, the visitor is created to allow a minimum of 0 and a maximum of infinity number of
arguments. If something else is wanted, this can be specified when creating the visitor:

    # only the visited
    @@label_visitor ||= Puppet::Pops::Visitor.new(self, "label", 0, 0)
    
    # the visited + one more
    @@eval_visitor ||= Puppet::Pops::Visitor.new(self, "eval", 1, 1)
    
    # the visited + at least one more
    @@variable_visitor ||= Puppet::Pops::Visitor.new(self, "variable", 1, nil)
    
By using these, the visitor will issue errors if there are too few or too many arguments when
calling visit. (If the optimized `visit_this_0`, `visit_this_1`, etc. are used, you will instead
get a runtime error from Ruby if the argument count does not match up).

### The Visitor's First Argument - the default receiver

The first argument to the `Visitor` is the default receiver. It only plays a role when using
the simple `visit` method, and can be specified as `nil` when constructing the `Visitor` if the
receiver is given in each call to `visit_this`.

### Visiting With Additional Arguments

You probably already guessed that if you want to pass additional arguments, they are simple
given in the call to visit. Here is an example from the evaluator:

    def evaluate(target, scope)
      @@eval_visitor.visit_this_1(self, target, scope)
    end
    
### Multiple Visitors and Other Patterns

It is perfectly ok to have multiple visitors in the same strategy. As an example, the evaluator
has visitors for "eval", "lvalue", "assign", and "string". 

Something complex can be handled with delegation to other strategies as this allows composition
of the wanted behavior. Again as an example, the evaluator delegates to `CompareOperator`, `RelationshipOperator`, and `AccessOperator` which are strategies for these operations. The first
two were factored out into separate strategies simply because of readability of the code (the 
`CompareOperator` adds three visitors "equals", "compare", and "include"), and the `RelationshipOperator` needs to perform operations that are specific to it. Including those in
the main evaluator would result in it dealing with mixed concerns.

As an example, here is how the `ComparisonOperator` is used in the evaluator:

      case o.operator
      when :'=='
        @@compare_operator.equals(left,right)
      when :'!='
        ! @@compare_operator.equals(left,right)
      when :'<'
        @@compare_operator.compare(left,right) < 0
      when :'<='
        @@compare_operator.compare(left,right) <= 0
      when :'>'
        @@compare_operator.compare(left,right) > 0
      when :'>='
        @@compare_operator.compare(left,right) >= 0
      else
        fail(Issues::UNSUPPORTED_OPERATOR, o, {:operator => o.operator})
      end

(The call to `fail` will be covered in a future post that covers error handling).

Lastly, the `AccessOperator` (which represents expressions in the Puppet Programming Language on the form `expression [ expression, expression ...]`)
needs to maintain state in order to be able to provide good error messages in case of a failure that relates to one of the evaluated expressions passed as an argument. Here is an example of how it is used in the evaluator:

    # Evaluates x[key, key, ...]
    #
    def eval_AccessExpression(o, scope)
      left = evaluate(o.left_expr, scope)
      keys = o.keys.nil? ? [] : o.keys.collect {|key| evaluate(key, scope) }
      Puppet::Pops::Evaluator::AccessOperator.new(o).access(left, scope, *keys)
    end

This may be changed since it may be faster to not create the strategy and instead pass
an extra argument in each call - more benchmarking will tell.

### Calling the "super" Version

Sometimes it is required to call a super version of a polymorph method. Here is
an example:

    def doit_Base(o)
      ...
    end
  
    def doit_Special(o)
      doit_Base(o) ...
    end

It is the responsibility of the implementor to ensure that the right "super" method is called
(i.e. that `Special` is indeed a specialization of `Base`). It is also the responsibility of
the implementor to check when method are added if there are any direct calls to "super" versions
that needs to be rewired (say if the class hierarchy is changed).

### Last Part of Class Name, Feature or Flaw?

A decision was made to make the `Visitor` only use the last part of the class name. This means it is
incapable of differentiating between two classes in different name spaces if they share the same name. This is both a feature (a strategy can be compatible with two different implementations)
and a flaw (when used with 3d party classes that were not designed with unique class names).

In practice, this has not been a limitation in the implementation of the parser/evaluator. If later
required, the `Visitor` could be made aware of additional segments in the name. This would probably
need to be a specialized `Visitor` as it would be slightly less performant.

### Strategy Composition

Since our strategies are separate instances we can easily pass them around. We can compose the
behavior we want and pass the strategies as arguments instead of having to rely on "the one and
only possible implementation" (which is what we get if we reference a class or module by name). We may want to have say a debugging version of the label provider
where we output additional information. Exactly how we compose strategy objects and wire them
into the logic where we want them to be used is for a later post where I am going to be talking about "inversion of control", and "injection". We could do something simple like this:

     class SomeClass
       def initialize(label_provider = DefaultLabelProvider.new)
         @label_provider = label_provider
       end
       
       def some_work(x)
         # ooops
         raise SomeError, "There is something wrong with the #{@label_provider.label(x)}."
       end
     end

### Summary

In this post, the concept of *polymorphic dispatch* was introduced; basically moving methods
from a set of classes to a common strategy where a visitor is used to dispatch the calls as if the methods were in their original place inside the classes - or to be more accurate, to the same effect
as if they were in their original places.

This organization ensures that strategies do not clash, and we get a design with low coupling, and
high cohesion; two desirable measures of architectural quality.

### In the Next Post

In the next post, I will explain the *Adapter* pattern which is another technique to
separate concerns. 