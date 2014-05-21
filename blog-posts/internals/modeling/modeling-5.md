In this post about Modeling with Ecore and RGen I will show how do achieve various common
tasks. Don't worry if you glanced over the the very technical previous post about the `ECore` model, If needed, I will try to repeat some of the information, but you may want to go back to it for details.

### Derived Attributes

Sometimes we need to use derived (computed) attributes. Say we want to model a `Person` and
record the birth-date, but we also like to be able to ask how old a `Person` is right now. To do this we would have two attributes `birth_date`, and a derived attribute `age`.

    class Person < MyModelElement
      has_attr 'birth_date', Integer
      has_attr 'age', Integer, :derived => true
    end
    
(Here I completely skip all aspects of handling date/time formats, time zones etc., and simply
use a date/time converted to an `Integer`).

Since a derived attribute needs to be computed, and thus requires us to implement a method, we must define this method somewhere.
All logic for a modeled class should be defined in a module called `ClassModule` nested inside the class. The definition in this module will be mixed into the runtime class.

A derived attribute is implemented by defining a method with the same name as the attribute plus
the suffix `'_derived'`.

The full definition of the `Person` class then looks like this:

    class Person < MyModelElement
      has_attr 'birth_date', Integer
      has_attr 'age', Integer, :derived => true
      
      module ClassModule
        def age_derived
          Time.now.year - birth_date.year
        end
      end
    end
    
Derived attributes are good for a handful of intrinsic things like this (information that is very closely related / an integral part of the class), but it should not be overused as we in general want our models to be as *anemic* as possible; operations on models are best implemented outside of the model as functions, the model should really just contain an implementation that maintains its integrity and provides intrinsic information about the objects.

Here is an another example from the new Puppet Type System:

    class PRegexpType < PScalarType
      has_attr 'pattern', String, :lowerBound => 1
      has_attr 'regexp', Object, :derived => true

      module ClassModule
        def regexp_derived
          @_regexp = Regexp.new(pattern) unless @_regexp && @_regexp.source == pattern
          @_regexp
        end
      end
    end

Here, we want to be able to get the real Ruby Regexp instance (the `regexp` attribute) from the `PRegexpType` based on the pattern that is stored in string form (`pattern`). Derived attributes are by default also virtual (not serialized), volatile (they have no storage in memory), and not changeable (there is no setter).

Here is an example of using the `PRegexpType`.

    rt = Puppet::Pops::Types::PRegexpType.new(:pattern => '[a-z]+')
    the_regexp = rt.regexp
    the_regexp.is_a?(Regexp)      # => true

Going back to the implementation. Remember, that all features (attributes and references) that are marked as being derived, must have a defined method named after the feature and with the suffix _derived. Thus, in this example, since the attribute is called `'regexp'`, we implement the method `'regexp_derived'`. Since we do not have any storage and no generated supporting methods to read/write the `Regexp` we need to create this storage ourself. (Note that we do not want to recompile the `Regexp` on each request unless the pattern has changed). Thus, we assign the result to the instance variable `@_regexp`. The leading `_` has no special technical semantics, but it is there to say 'hands off, this is private stuff'.

### Adding Arbitrary Methods

You can naturally add arbitrary methods to the `ClassModule`, they do not have to be derived features. This does however go against the anemic principle. It also means that the method is not
reflected in the model. Such methods are sometimes useful as private implementation method
that are called from methods that represent derived features, or that are for purely technical Ruby runtime reasons (as you will see in the next example).

### Using Modeled Objects as Hash Keys

In order for something to be useful as a hash key, it needs to have a hash value that reflects
the significant parts of the object "as a key". Regular Ruby objects use a default that is typically
not what we want.

Again, here is the `PRegexpType`, now also with support for being a hash key.

    class PRegexpType < PScalarType
      has_attr 'pattern', String, :lowerBound => 1
      has_attr 'regexp', Object, :derived => true

      module ClassModule
        def regexp_derived
          @_regexp = Regexp.new(pattern) unless @_regexp && @_regexp.source == pattern
          @_regexp
        end

        def hash
          [self.class, pattern].hash
        end

        def ==(o)
          self.class == o.class && pattern == o.pattern
        end
      end
    end

This implementation allows us to match `PRegexpType` instances if they are a) of the same class,
and b) have the same source pattern. To support this, we simply create a hash based on the
class and pattern in an `Array`. We also need to implement `==` since it is required that two objects that have the same hash also compute true on `==`.

Can you think of improvements to this implementation?

(We do compute the hash value on every request, we could cache it in an instance variable. We must then however ensure that if pattern is changed, that we do not use a stale hash. In order to
to know we must measure if it is faster to recompute the hash, than compute if the pattern
has changed - this is an exercise I have yet to do).

### Overriding Setters

Another use case is to handle setting of multiple values from a single given value - and worst case setting them cross-wise. (Eg. in the example with the Person, imagine wanting to set either the 
birth_date or computing from a given age in years - yeah it would be a dumb thing to do, but I had to come up with a simple example).

Here is an example from the AST model - again dealing with regular expressions, but now in
the form of an instruction to create one. 

    # A Regular Expression Literal.
    #
    class LiteralRegularExpression < LiteralValue
      has_attr 'value', Object, :lowerBound => 1, :transient => true
      has_attr 'pattern', String, :lowerBound => 1

      module ClassModule
        # Go through the gymnastics of making either value or pattern settable
        # with synchronization to the other form. A derived value cannot be serialized
        # and we want to serialize the pattern. When recreating the object we need to
        # recreate it from the pattern string.
        # The below sets both values if one is changed.
        #
        def value= regexp
          setValue regexp
          setPattern regexp.to_s
        end

        def pattern= regexp_string
          setPattern regexp_string
          setValue Regexp.new(regexp_string)
        end
      end
    end
    
Here you can see that we override the regular setters `value=`, and `pattern=`, and that these
methods in turn use the internal methods `setValue`, and `setPattern`. This implementation is however not ideal, since the `setValue` and `setPattern` methods are also exposed, and if they are called the attributes `value` and `pattern` will get out of sync!

We can improve this by doing a renaming trick. We want the original setters to be callable, but only from methods inside the class since we want the automatic type checking performed by
the generated setters.

    module ClassModule
      alias :setPattern :_setPattern_private
      private :_setPattern_private
      
      alias :setValue :_setValue_private
      private :_setValue_private

      def setPattern(regexp_string)
        _setPattern_private(regexp_string)
        _setValue_private(Regexp.new(regexp_string))
      end
      
      def setValue(regexp)
        _setValue_private(regexp)
        _setPattern_private(regexp.source)
      end
    end      

Here we squirrel away the original implementations by renaming them, and making them
private. Since we did this, we do not have to implement the `value=` and `pattern=` methods
since they default to calling the set methods we just introduced.

Now we have a safe version of the `LiteralRegularExpression`.
      
### Defining Relationships Out of Band

Bi-directional references are sometimes tricky to define when there are multiple relations.
The classes we are referencing must be known by Ruby and sometimes the model is not a a hierarchy. And even if it is, it is more natural to define it top down than bottom up order.

To handle this, we need to specify the relationships out of band. This is very easy in Ruby since classes can be reopened, and it especially easy with RGen since the builder methods are available
for modifying the structure that is built while we are building it.

Here is an example (from RGen documentation):

    class Person < RGen::MetamodelBuilder::MMBase
      has_attr 'name', String
      has_attr 'age', Integer
    end

    class House < RGen::MetamodelBuilder::MMBase
      has_attr 'address', String
    end

    Person.many_to_many 'homes', House, 'inhabitants'
    
What RGen does is to simply build the runtime model, for some constructs with intermediate meta-data 
recording our desire what our model should look like. The runtime classes and intermediate meta-data is then mutated until we have completed the definition of the model. The runtime classes are ready to use as soon as they are defined, but caution should be taken to use the classes for anything while the module they are in is being defined (classes may be unfinished until the very end of the module's body). Then, the first request to get the meta-model (e.g. calling `Person.class.ecore`) will trigger the building of the actual meta-model as an `ECore` model).  It is computed on demand, since if it is not needed by the logic (only the concrete implementation of it), there is little point taking cycles to construct it, or having it occupy memory.

As you may have guessed, it is a terribly bad idea to modify the meta-model after it has been defined
and there are live objects around. (There is nothing stopping you though if you know what you are doing). If you really need to jump through hoops like these, you need to come up with a scheme
that safely creates new modules and classes in different "contexts".

### In this Post

In this post I have shown some common tasks when using RGen. You should now have a grip on
how derived attributes are handled and how to provide implementation logic for the
declaratively modeled classes.

In a future post I will cover additional topics, such as dealing with custom data types,
serialization of models, and how to work with fragmented models. It may take a while before I post on those topics as I have a bit of exploratory work to do regarding how these features work in RGen. meanwhile, if you are curious, you can read about these topics in the [EMF book][3] mentioned in the [ECore blog post][2].

[2]:http://puppet-on-the-edge.blogspot.se/2014/05/puppet-internals-ecore-model.html
[3]:http://www.informit.com/store/emf-eclipse-modeling-framework-9780321331885
