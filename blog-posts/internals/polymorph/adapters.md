In this series of blog posts about the future parser/evaluator the turn has come to
*adapters*, a technique used to implement a *strategy pattern* that attaches an instance
of an `Adapter` to an object and where the original object's logic is kept unaware of this
attachment.
Part of the rationale for this is described in the previous post called ["Separation of Concerns"][0].
While the adapter pattern also is a functional composition pattern its main use is to allow
composition of state.

[0]:http://puppet-on-the-edge.blogspot.be/2014/01/puppet-internals-separation-of-concerns.html

### Using an Adapter

Let's start with an example creating and using a simple adapter.

The base implementation is found in the class `Puppet::Pops::Adaptable::Adapter`. Here is a simple
example where a `NickNameAdapter` is defined and used to associate a nick name with any object.

    # Defining the adapter
    class NickNameAdapter < Puppet::Pops::Adaptable::Adapter
      attr_accessor :nick_name
    end
    
    # Using the adapter
    d = Duck.new("Daphne")
    NickNameAdapter.adapt(d).nick_name = "Daffy"
    NickNameAdapter.get(d).nick_name             # => "Daffy"

Behind the scenes, the adapter will add one instance variable to the adapted object named
after the adapter class. (Or put differently, each subclass of `Adapter` manages one instance
of the adapter-class per adapted object). The naming ensures there are no clashes among
the various kinds of adapters.

While it is possible to achieve almost the same kind of separation using Ruby techniques,
the adapter pattern has one important difference when it comes to accidental coupling. The typical
Ruby solution would either be to open the original class and include a module, or if sparse allocation is wanted to open/create the eigen class (a.k.a instance-class), and then add instance variables
and / or logic there. While this Ruby construct keeps the source code free from mixing the concerns,
the end result is an object that has the aggregated behavior. This creates two problems:

* The names of attributes and methods may clash with some other concern - someone may later
  want to use a `StarWarsNickName` module that associates a nick name based on a Star Wars character.
  If this adapter also uses nick_name - they will clash.
* Logic that is unaware of the extension may unintentionally invoke such operations - especially
  so if the extension is of a generic kind (e.g. using names like `status`, `id`, or, `name`).
  Such logic is both tedious and difficult to hunt down later when refactoring takes place.
  
### Benefits of Using an Adapter

* The storage for an adapter is allocated when needed. This is ideal when only some objects need
  to carry extra data. (Real example - associating on-demand cached information
  that is derived from the object's intrinsic attributes that is expensive to calculate).
* The data and behavior captured in an adapter does not leak into the object itself (while it is 
  possible to find the instance variable, the methods that operate on it are not found in the adapted
  object/class).
* Does not require keeping a separate table of association between adapted instance and extra data.
  This is always problematic as it may cause memory leaks if objects are not managed in this table
  (they must be removed when they go out of scope).
  * An efficient table solution also requires that there is a unique key that allows a hash table
    to be used, or that the adapted object itself can work as a hash key. This may not always be
    the case.
* Makes refactoring easier since logic that makes use of the extended functionality must do so
  via use of the specific adapter.
* Should the logic ever be ported to another language then it is much easier to implement/use
  an adapter pattern then to try to add support for Ruby's open-and-extend concepts.
  
### The Adapter API

The Adapter API is quite simple, and consists of:

* `adapt` - creates adapter if needed, returns the adapter
* `adapt_new` - creates a new adapter (removes any previous adapter of the same type)
* `get` - returns the adapter or nil if not adapted
* `clear` - completely removes the association of this adapter type

The following methods are intended to be defined / overridden by the implementor of an adapter if
it has special needs.

* `create_adapter` - if something more special than a standard new/initialize is needed
* `instance_var_name` - if something special (like thread or context unique names) are needed
* `associate_adapter` - associates an adapter with an object

#### adapt, adapt_new

The class method `adapt` produces an instance of the adapter class associated with the given
object. If the object is not already adapted, a new adapter is created, otherwise the already
associated adapter is returned.

    MyAdapter.adapt(o)  

The adapt method optionally takes a block with one or two parameters. If one parameter is used,
this is given the value of the adapter, and if a second is used, it is given the adapted object.

    NickNameAdapter.adapt(o) { |a| a.nick_name = "Buddy!" }
    NickNameAdapter.adapt(o) { |a, o| a.nick_name = "You're the best #{o.class.name} I ever met."}

The `adapt_new` works the same way, but it always produces a new instance of the adapter and drops
the association with any previously associated adapter of the same type.

#### get

Simply returns the associated adapter if the given object has been adapted, and nil otherwise.
This is a convenient way to both test if an object is adapted, and get the adapter at the same
time.

    MyAdapter.get(o)  # nil, or an adapter of type MyAdapter
    
#### clear

Simply removes the adapter from the given object. (Technically done by removing the instance
variable). This is a no-op if the given object was not adapted.

    MyAdapter.clear(o)

#### create_adapter

This method can be overridden if something more elaborate is needed in a subclass of Adapter
when an instance of the adapter is created. The method is given the adapted object if
the adapter wants to configure itself from the object it is associated with.
The default `create_adapter` simply calls `new` without arguments.

#### associate_adapter

This method associates an adapter with the given object. It may be overridden if there
are special needs - this method must bind the adapter to the expected instance variable, but a
special implementation may also do other things.

#### instance_var_name

As shown earlier, the name of the created instance variable is based on the name of the class.
This method may be overridden if there is the need to use the same kind of adapter to manage multiple
states of the same kind, say to include the current thread. (An alternative solution is for
the adapter itself to manage such a thread to data mapping).

### Adapters and Models

I have yet to write a blog post about the ecore modeling technology used in Puppet (RGen), but here
is a small tidbit that relates to adapters.

Since the runtime support for objects that are modeled makes it possible to navigate
a complete structure (objects know if they are contained, in which object they are contained,
and the role that it plays - e.g. "I am the left front wheel of the Car RQT-324"). This also
goes the other way - it is possible to generically find "all contained objects", which for
a Car could mean, the four wheels, the engine, the seats etc. and the logic we are writing
can find these without knowing explicitly about the exact concepts (e.g. "wheels").

This makes it very easy to search for an adapter. As an example, we may have a TestReport
adapter that contains information about the condition of a part of a Car. Further, if a part
also can contain parts recursively and we are operating
on one part somewhere in this hierarchy, we may want to know if there is a report associated
with either the given part or a "parent part".

There is a small utility method for this in `Puppet::Pops::Utils` called find_adapter. It could
be used like this:

    part = ... # a reference to a car part
    adapter = Puppet::Pops::Utils.find_adapter(part, TestReportAdapter)
    if adapter
       # a report was associated with the part or one of its parent parts
       # ...
    end

This only works with modeled classes (such as the AST model used in the future parser) since
Ruby classes in general does not know anything about containment.

In a future blog post I will cover all the various ways a model can be navigated
by making use of the ecore meta-model that is associated with modeled objects. (As an example, say
how to write a method that finds any/all contained object that has an associated adapter).

### When not to use an Adapter

There are scenarios where an `Adapter` is not the best choice. They are slightly slower than
using directly implemented support for a concern - so in performance critical parts purity
in design may need to be sacrificed. 

Naturally, if something is really an intrinsic part of some other object, then it should
probably be implemented directly, or via explicit composition - say when the system we are writing
is all about producing test reports for car parts.

### Summary

The adapter pattern is a mechanism that provides separation of both data and functional concerns.
It is ideal for extending functionality with additional aspects where it is undesirable to
mix the concern into targeted classes. It is also good for dealing with sparsely extended
populations (where only some / few out of all instances needs to be extended).

In the Puppet runtime for the "future parser/evaluator" adapters are currently only used for
caching of computed source locations, but is also intended to be used for things like
association of validation results (i.e. errors), loader (which loader loaded the code), and
perhaps documentation. There are many additional constructs in the Puppet runtime that would
benefit from the use of the adapter pattern and you may be seeing them in additional places
as more code is refactored to reduce coupling and increase cohesion in the Puppet code base.

### In the Next Post

In the next post, I will cover how the `SourcePosAdapter` is used to cache detailed source position
information associated with individual expressions parsed from puppet source code.

