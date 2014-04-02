Context and Scope
---
We currently have a very complicated way of booting the puppet runtime, and once booted
we have a complex and much overloaded implementation that revolves around:

* Settings
* Node
* Environment
* Scope
* Compiler
* Parser / Evaluator
* "bindings"
* "known_resource_types"
* "loading"
* "functions"

We have been discussing how we can clean up the implementation with the following goals:

* make it easier to understand what is going on
* make it possible to specify real APIs that are smaller than "everything"
* complex bootstrapping where things are done multiple times? (unclear sequencing)
* reduce bloat (almost the same behavior implemented in multiple places)
* decrease cohesion by increased use of composition and dependency injection
* make implementation of new features possible:
  * real closures
  * pass arguments in a more sane way to functions
  * provide support for "private" resource types, classes and variables
  * name-spaced functions and possibly name-spaced types
  * restrict modules to only see what they specify in their dependencies
  
As you can see, there is a mix of internal goals; "reduce cost of maintenance", "increase speed
of innovation", "reduce risk of introducing new bugs", "make it easier to understand and work with", and real wanted features.

## Idea 1 - Context

A Context has already been introduced in the code base to solve a particular problem. The idea
is to formalize and extend the capabilities around the Context.

The idea is that a Context represents the configuration of the runtime for the purpose of
servicing a particular request. A very large percentage of the code base needs this context,
and it is unreasonable to pass it around in every call everywhere - especially when passing 3d
party implementations and coming out on the other side without a reference to context.

Instead, there is always a reference to the current context in a thread local variable.

A Context refers to its parent context, and is grounded at the RootContext (or BootContext, SystemContext or some-such name). As the system progresses in processing a particular request
it creates a more specialized context parented by the current context, configures it, sets it as the current context, and then continues with the processing of the request.

At the edge, this could mean that there is a RootContext <- HttpContext when the system
is performing a request that came in over HTTP. If the request originated from the command line,
there may be some other kind of context. As the request continues to be serviced, say a request for
a catalog - the logic is aware that a configuration is needed to deal with parsing, evaluation etc.
A yet more specialized context is created, set as current (etc.).

This creates a context stack where the top of the stack is always available via the thread local
variable. Logic that needs to know if the request being processed is within a particular context
can query for it by asking for "context of type". (This is better than blindly calling methods
on the current context because it enables catching system configuration errors).

Say, the logic needs to find the Compiler:

    compiler = context.get(Puppet::Context::CompilingContext).compiler
    
If there is no CompilingContext the runtime stops with a ConfigurationError.

This is the basic idea - there is more to say about the different kinds of contexts.

## Idea 2 - Scope

The current Puppet::Parser::Scope is a very overloaded implementation. Its major flaw is
that the scope stack is internal to the scope and it changes over time. This makes it impossible
to support a proper closure for lambdas (they may not be remembered and used later since the context
they refer to may be/is lost). 

The implementation itself is also quite convoluted with multiple ways of asking - "is set", "is
it there", "if not where" etc. Scope is also to some degree responsible for the policy what should
happen if "not there", or "elsewhere".

Scope internally has implementation of EphemeralScope that act more like a traditional scope
implementation. The idea is to break all of this logic apart.

Scope should be a very simply construct. There are subclasses of scope used for various purposes.

* `NamedScope` - a scope that is a top level scope that can be found via its name as reference. Its
  content is visible to anyone that finds it.
* `InnerScope` - a scope that is parented by a named scope, it contains private variables
  only visible
  to the interior of the construct that created the NamedScope. This scope can not be looked up
  externally, it is only visible while evaluating the logic in the named scope. When setting non
  private variables, they are set in the parent scope (the named scope).
* `LocalScope` - a scope that can not be looked up externally, all variables are by definition
  private (unless we also want private variables to be invisible for inner/nested scopes; languages
  typically do not work that way).
* `MatchScope` - a scope that refers to a MatchData - the result of the last regexp match. (See below
  for more information).
  
### Scope API

    # name String, value Object, options :private, :final
    set_variable(name, value, options)

    # key !String, value Object, options :private, :final    
    set_data(key, value, options)
    
    # is key found in this or parents
    exist?(key_or_name)
    
    # is key found in this
    exist_locally?(key_or_name)
    
    # get value associated with 'key_or_name' or nil if not found
    get(key_or_name)
    
    # get entry (a ScopedObject) or nil if not found in this or parents
    get_entry(key_or_name)
    
    # Enumerator over local keys if no block is given
    each_local_key &block
    
    # Enumerator over local keys and parent keys if no block given
    each_key &block
    
    # MatchData or nil
    current_match()

    # Sets match data (the only mutable variable)
    current_match=(MatchData)
    
    # the current context
    context()
    
    # the Puppet Programming Language injector
    injector()

* MatchData variables are never included in the enumeration
* String and Numeric keys are variable names, automatic coercion between numeric in string form
  and numeric
* Handling of inherited scope remains to be designed (the inherited scope could be
  handled as a parent scope - i.e. the `NamedScope` if its private variables are not visible,
  and it's `InnerScope` if they should be visible (probably not)).
  
#### ScopedObject

    private?()
    final?()
    value()
    key()
    
#### MatchData

The current implementation has a mechanism where a stack point into the ephemeral stack
can be obtained and later used to reset the scope's internal scope stack. This is done
to provide match data that is specific to certain nested structures (if, unless, case, selector),
and to reset when the structure goes out of scope. The implementation has a problem in that
a sequence of expression like

    $a = 'x' =~ /.*/
    $b = 'x' =~ /.*/
    # ...
    
Will push a new match scope for each match (since there is no defined end of the match
scope). 

This implementation is because the logic is deep down in match, and does not know what to do
except to push a new match scope on the internal stack (hoping that it is reset by someone else
later). Naturally, this is one of the problems with supporting real closures.

What we want is that the next match in the same scope should override the match, not push
a new scope.

We can implement this by making "match data" be the only mutable variable. In a NamedScope,
the match data is set on the InnerScope. This guarantees that numeric match variables
are invisible when doing an "external lookup". In all other scopes it is simply set.

This leaves one problem, the scopes created for if, unless, case, selector cannot be a
`LocalScope` since if it sets variables, they should be set in the outer scope. The solution is
simple, we just push a new `InnerContext` onto the scope stack at the start of evaluation of
such an expression (in contrast to getting the now internal stack pointer and doing a reset).


## Back to Contexts

All Contexts supports access to an Injector. This is the system injector which contains
bindings for the runtime (as opposed to bindings for the Puppet Programming Language).

The Context implementation that support compilation (there may be an intermediate context
that knows how to parse code, one that allows evaluation of code (sans catalog/compilation). 
(Subject to details when doing the implementation). The concepts that some implementation of
Context needs to handle are:

* Loader - which loader to use if a specialized loader is not known (the global default loader).
  (More about loaders below).
* (TBD) Finding/creating configuring loaders for modules etc. 
* NamedScope lookup
* Reference to Compiler

## Loaders

If we want to support that modules only see what they have declared dependencies on the loading
of code cannot simply use one and only one global loader (like it does now). Instead, each
module should have its own resolved "module path" that together with higher level loaders (global,
per environment, etc.) defines the visibility and loading scope.

This means that:

* whenever a "type" is needed it is requested from a loader
* the loader caches what it has loaded
* the visibility of what is loaded is composed
* loading is constrained to look in a particular set of places

It also means that:

* We must know which loader loaded the code that is being evaluated

The last part is simple. When the loader loads something it uses a LoaderAdapter to decorate
the root of what has been loaded with a reference to the loading loader. (For PuppetLogic in
the "future parser" this is a Puppet::Pops::Model::Program, and all other expressions under it
can navigate to this root node when the loader is required - the Program is usually only 
a few hops away, but could potentially be cached at lower levels in the tree in case excessive
loading from a deeply nested expression is found to be a real world problem).

The loader domain relates to the book-keeping of "in which module is this logic" which is currently
done with variables stored in the scope. This is also where "caller_module_name" is stored.


## Further work

The relationship between Node, Class, Define and scope is also subject to entangled logic.
It seems much clearer if they were real objects instead of a magic combination of a Resource
and a Scope. 