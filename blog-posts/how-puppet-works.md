Getting your Puppet Ducks in a Row
===
A conversation that comes up frequently is if the Puppet Programming Language is declarative or not. This is usually the topic when someone has been fighting with how order of evaluation works and have
been beaten by what sometimes may seem as random behavior. In this post I want to explain how
Puppet works and try to straighten out some of the misconceptions.

First, lets get the terminology right (or this will remain confusing). It is common to refer to "parse order" instead of "evaluation order" and the use of "parse order" as a term is deeply rooted in the Puppet community - this is unfortunate as it is quite misleading. A language is first parsed and then evaluated, and as you will see, almost all of the peculiarities occur during evaluation.

### "Parse Order"

Parse Order is the order in which Puppet reads puppet manifests (`.pp`) from disk, turns them into tokens and checks their grammar. The result is something that can be evaluated (technically an Abstract Syntax Tree (AST)). The order in which this is done is actually of minor importance from a user perspective, you really do not need to think about how an expression such as `$a = 1 + 2` becomes an AST.

OTOH, if you think about "parse order" as "the order the files are parsed", but this order is
also of minor importance. Puppet starts with the `site.pp` file (or possibly the `code` setting in the configuration), then asking external services (such as the ENC) for additional things that are not included in the logic that is loaded from the `site.pp`. In versions from 3.5.0 the manifest setting can also refer to a directory of `.pp` files (preferred over using the now deprecated `import` statement).

At this point (after having started and after having parsed the initial manifest(s), Puppet first matches the information about the node making a request for a catalog with available node definitions, and selects the first matching node definition. At this point Puppet has the notion of:

* node - a mapping of the node the request is for.
* a set of classes to include and possibly parameters to set that it got from external sources.
* parsed content in the form of one or several ASTs (one per file that was initially parsed)

Evaluation now starts of the puppet logic (evaluation of the ASTs). This evaluation order is imperative - lines in the logic are executed in the order they are written. Classes and Defines are defined as a consequence, but they are not evaluated (i.e. their bodies of code are just associated with the respective name and set aside for later "lazy" evaluation).

### Definition and Declaration

In computer science these term as used as follows:

* Declaration - introduces a named entity and possibly its type, but it does not fully define
  the entity (its value, functionality, etc.)
* Definition - binds a full definition to a name (possibly declared somewhere). A definition is what
  givens a variable a value, or defines the body of code for a function.

A user defined resource type is defined in puppet using a `define` expression. E.g something like
this:

    define mytype($some_parameter) {
      # body of definition
    }

A host class is defined in puppet using the class expression. E.g. something like this:

    class ourapp {
      # body of class definition
    }

However, if we at a point after that resource type definition or class definition have been made
try to ask if `mytype` or `ourapp` is defined by using the function `defined`, we will be told that it is not! This is because the implementor of the function `defined` used the word in a very ambiguous manner - **the defined function actually answers "is it in the catalog?", not "do you know what a mytype is?"**.

The terminology is further muddled by the fact that the result of a resource expression is computed in two steps - the instruction is queued, and later evaluated. Thus, there is a period of time
when it is defined, but what it defines does not yet exist (a kind of recorded desire / partial evaluation). The `defined` function will however return true for resources that are in the queue

     mytype { '/tmp/foo': ...}
     notice defined(Mytype['tmp/foo'])  # true
     
When this is evaluated, a declaration of a mytype resource is made in the catalog being built. The
actual resource '/tmp/foo' is "on its way to be evaluated" and the `defined` function returns `true` since it is "in the catalog" (only not quite yet).

Read on, to learn more, or skip to the example if you want something concrete and then come back and read about "Order of Evaluation".

### Order of Evaluation
 
In order for a class to be evaluated, it must be included in the computation via a call to `include`, or by being instantiated via the resource instantiation expression. (In comparison to a classic Object Oriented programming language `include` is the same as creating a new instance of the class). Also note that instances of Puppet classes are singletons (a class can only be instantiated once in one catalog).

If something is not included, then nothing that it in turn defines is visible. Originally, there was no "instantiate class as a resource" expression, only the `include` function call - and the idea was that you could include the class as many times you wanted (since there can only be one instance, the
include call only repeats the desire to include that single instance). You always included a class before attempting to use it. Now, with parameterized classes, this does not work because classes are singletons and can thus not be instantiated with different sets of parameters (that would require having more than one instance). Unfortunately puppet cannot handle this even if the parameters are identical, or if it does not have any parameters at all - it sees this as an attempt of creating a second (illegal) instance of the class.

When something includes a class (or uses the resource instantiation expression to do the same), the class is auto-loaded; this means that puppet maps the name to a file location, parses the content, and expects to find the class with a matching name. When it has found the class, this class is evaluated (its body of code is evaluated).

The result of the evaluation is a catalog - the catalog contains resources and edges and is declarative. The catalog is transported to the agent, which applies the catalog. The order resources are applied is determined by their dependencies (and their containment, use of anchor pattern, or the `contain` function, and settings (apply in random, or by source order, etc.). No evaluation of any puppet logic takes place at this point (at least not in the current version of Puppet) - on the agent the evaluation is done by the providers operating on the resource in the order that is determined by the catalog application logic running on the agent.

**The duality of this; a mostly imperative, but sometimes lazy production of a catalog and a declarative catalog application is something that confuses many users.**

As an analog; if you are writing a web service in PHP, the PHP logic runs on the web server and produces HTML which is sent to the browser. The browser interprets the HTML (which consists of declarative markup) and makes decision what to render where and in which order the rendering
will take place (images load in the background, some elements must be rendered first because their size is needed to position other elements etc.). Compared to Puppet; the imperative PHP backend corresponds to the master computing a catalog in a mostly imperative fashion, and an agent's application of the declarative catalog corresponds to the web browser's rendering of HTML.

Up to this point, the business of "doing things in a particular order" is actually quite clear.
What still remains to be explained is the order in which the bodies of classes and user defined types are evaluated, as well as when relationships and queries are evaluated.

### Producing the Catalog

The production of the catalog is handled by what is currently known as the "Puppet Compiler". This is again a misnomer, it is not a compiler in the sense that other computer languages have a compiler that translates the source text to machine code (or some intermediate form like Java Byte Code). It does however compile in the sense that it is assembling something (a catalog) out of many pieces of information (resources). Going forward (Puppet 4x) you will see us referring to **Catalog Builder** instead of Compiler - who knows, one day we may have an actual compiler (to machine code) that compiles the instructions that builds the catalog. Even if we do not, for anyone that has used a compiler it is not intuitive that the compiler runs the program, which is what the current Puppet Compiler does.

When puppet evaluates the AST, it does this imperatively - `$a = $b + $c`, will immediately look up the value of $b, then $c, then add them, and then assign that value to `$a`. The evaluation will use the values assigned to `$b` and `$c` at the time the assignment expression is evaluated. There is nothing "lazy" going on here - it is not waiting for `$b` or `$c` to get a value that will be produced elsewhere at some later point in time.

Some instructions have side effects - i.e. something that changes the state of something external to the function. An operation like `+` is a pure function - it takes two values and adds them, once this is done there is no memory of that having taken place (unless the result is used in yet another expression, etc. until it is assigned to some variable (a side effect).

The operations that have an effect on the catalog are evaluated for the sole purpose of their side effect. The `include` function tells the catalog builder about our desire to have a particular class included in the catalog. A *resource expression* tells the catalog builder about our desire to have a particular resource applied by the agent, a dependency formed between resources again tells the catalog builder about our desire that one resource should be applied before/after another. While the instructions that cause the side effects are immediate, the side effects may be recorded for later action. This is the case for most operations that involve building a catalog.

In other words, **expressions that perform catalog operations are (mostly) lazy**

* An `include` will evaluate the body of a class (since classes are singletons this happens only 
  once).  The fact that we have instantiated the class is recorded in the catalog - a class is a 
  container of resources, and the class instance is fully evaluated and it exists as a container, but 
  it does not yet contained the actual resources. In fact, it only contains *instructions*
  (i.e. our desire to have a particular resource with particular parameter values to be applied on 
  the agent).
* A class included via what looks like a resource expression i.e. `class { name: }` behaves
  like the `include` function wrt. evaluation order.
* A dependency between two (or a chain of) resources is also *instructions* at this point.
* A query (i.e. space-ship expressions) are *instructions* to find and realize resources.

The catalog building reaches a point where it starts processing. Processing begins by processing the queued up instructions to evaluate resources. Since a resource may be of user defined type, and it in turn may include other classes, the processing of resources gets interrupted and those classes are evaluated (this typically adds additional resource instructions to the queue). This continues until all instructions about what to place in the catalog have been evaluated (and nothing new was added).
The lazy evaluation of the catalog building instructions are done in the order they were added to the catalog with the exception of queries and relations which are done at the very end.


### How many different Orders are there?

The different orders are:

* **Parser Order** - a more or less insignificant term meaning the order in which text is translated
  into something the puppet runtime can act on. (If you have a problem with ordering, you are
  almost certainly not having a problem with parse order).
* **Evaluation Order** - the order in which puppet logic is evaluated with the purpose of producing
  a catalog.
* **Catalog Build Order** - in which order the catalog builder evaluates definitions. (If you are 
  having problems with ordering, this is where things appears to be mysterious).
* **Application Order** - the order in which the resources are applied on an agent (host). (If you 
  are having ordering problems here, they are more apparent, "resource x" must come before
  "resource y", or something (like a file) that "resource y" needs will be missing).
  Solutions here are to use dependencies, the anchor pattern, or use the `contain` function.)

### Please Make Puppet less Random!

This is a request that pops up from time to time. Usually because someone has blown a fuse over
a Catalog Build Order problem. As you have learned, the order is far from random. It is however,
still quite complex to figure out the order, especially in a large system. Is there something we can do about this?

Since the mechanisms in the language has been out there for a while, it is not an easy thing to change, there are many that rely on the current behavior - there are however many ways around the pitfalls that work well for people creating complex configurations - i.e. there are "best practices". There are also things that are impossible or difficult to achieve.

There are many suggestions about how the language should change to be both more powerful and easier to understand, and several options are being considered to help with the mysterious Catalog Build
Order and the constraints it imposes. These options are:

* Being able to include a resource multiple times if they are identical (or that they augment each 
  other).
* Make a class include taking place before a class has been instantiated as a resource to be   
  considered identical (since the include did not specify any parameters it can be considered as
  a desire of lower precedence). (It is currently possible allowed to do the reverse).

Another common request is to support decoupling between resources, sometimes referred to as "co-op",
where there is a desire to include things "if they are present" (as oppose to someone explicitly including them). The current set of functions and language mechanisms makes this hard to achieve (due to Catalog Build Order being complex to reason about).

Here the best bet is the ENC (for older versions), or the Node Classifier for newer puppet versions. Related to this is the topic of "data in modules" which in part deals with the overall composition of the system. The features around "data in modules" have not been settled while there are experimental things to play with - none of the existing proposals is a clear winner.
 
I guess this was a long way of saying - we will get to it in time. What we have to do first (and what we are working on) is the semantics of evaluation and catalog construction. At this point, the new evaluator (that evaluates the AST) is available when using the --parser future flag in the just released 3.5.0. We have just started up the work on the new Catalog Builder where we will more clearly (with the goal of being more strict and deterministic) define the semantics of the catalog and the process that constructs it. We currently do not have "inversion of control" as a feature (i.e. by adding a module to the module path you also make its starting point included), but are well aware of this feature being much wanted (in conjunction with being able to compose data).

What better way to end than with a couple of examples...

### Getting Your Ducks in a Row

Here is an example of a manifest containing a number of ducks. In which order will they appear?

    define duck($name) {
      notice "duck $name"
      include c
    }
    
    class c {
      notice 'in c'
      duck { 'duck0': name => 'mc scrooge' }
    }
    
    class a {
      notice 'in a'
      duck {'duck1': name => 'donald' }
      include b
      duck {'duck2': name => 'daisy' }
    }
    
    class b {
      notice 'in b'
      duck {'duck3': name => 'huey' }
      duck {'duck4': name => 'dewey' }
      duck {'duck5': name => 'louie' }
    }
    
    include a

This is the output:

    Notice: Scope(Class[A]): in a
    Notice: Scope(Class[B]): in b
    Notice: Scope(Duck[duck1]): duck donald
    Notice: Scope(Class[C]): in c
    Notice: Scope(Duck[duck3]): duck huey
    Notice: Scope(Duck[duck4]): duck dewey
    Notice: Scope(Duck[duck5]): duck louie
    Notice: Scope(Duck[duck2]): duck daisy
    Notice: Scope(Duck[duck0]): duck mc scrooge

(This manifest is found [in this gist][1] if you want to get it an play with it yourself).

Here is a walk through:
* class a is included and its body starts to evaluate
* it placed duck1-donald in the catalog builder's queue
* it includes class b and starts evaluating its body (before it evaluates duck2 - daisy)
* class b places ducks 3-5 (the nephews) in the catalog builder queue
* class a evaluation continues, and duck 2-daisy is now placed in the queue
* the evaluation is now done, and the catalog builder starts executing the queue
* duck2-donald is first, this logs is name, and class c is included
* class c queues duck0-mc scrooge
* catalog now processes the remaining queued ducks in order 3,4,5,2,0

[1]:https://gist.github.com/hlindberg/9975348

The order in which resources are processed may seem to be random, but now you know the actual rules.

### Getting Parameters from Resources

In the future parser/evaluator in Puppet 3.5.0 it is possible to access the evaluated parameter values of a resource. As you probably have guessed, using this feature is tricky because of the queuing of resource evaluation. There is currently no function that answers the question "is this resource evaluated" so you must be very sure that you only use this feature in a resource body where you know that it is queued after the resource you want to get a parameter from.

As an example, if you want to get the name of a Duck, this is what you write:

    notice "Name of duck duck1 is ${Duck[duck1][name]}"
    
In the example above, if you define `allducks` as a resource type like this:

    define allducks {
      Integer[0,5].each |$index| {
        $name = Duck["duck${index}"][name]
        notice "Name of duck duck${index} is ${$name}"
      }
    }
    
and then add that resource last in class c, like this:

    class c {
      notice 'in c'
      duck { 'duck0': name => 'mc scrooge' }
      allducks {'all-the-ducks': }
    }

the following output is produced:

    Notice: Scope(Class[A]): in a
    Notice: Scope(Class[B]): in b
    Notice: Scope(Duck[duck1]): duck donald
    Notice: Scope(Class[C]): in c
    Notice: Scope(Duck[duck3]): duck huey
    Notice: Scope(Duck[duck4]): duck dewey
    Notice: Scope(Duck[duck5]): duck louie
    Notice: Scope(Duck[duck2]): duck daisy
    Notice: Scope(Duck[duck0]): duck mc scrooge
    Notice: Scope(Allducks[all-the-ducks]): Name of duck duck0 is mc scrooge}
    Notice: Scope(Allducks[all-the-ducks]): Name of duck duck1 is donald}
    Notice: Scope(Allducks[all-the-ducks]): Name of duck duck2 is daisy}
    Notice: Scope(Allducks[all-the-ducks]): Name of duck duck3 is huey}
    Notice: Scope(Allducks[all-the-ducks]): Name of duck duck4 is dewey}
    Notice: Scope(Allducks[all-the-ducks]): Name of duck duck5 is louie}

### Summary

In this (very long) post, I tried to explain "how puppet really works", and while the order in which puppet takes action may seem mysterious or random at first, it is actually defined and deterministic - albeit quite intuitive when reading the puppet logic at face value.
 