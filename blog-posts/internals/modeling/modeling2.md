In the previous post about modeling I covered the basic principles of models, i.e. - 
A model is an abstraction, a model that describes a model is a meta-model, and finally
a model that defines the grammar for how meta-models are written is called a meta-meta model.

Since this may sound like hocus-pocus, I am going to show concrete examples of how this works.
Before we can start doing tricks with meta-models, we must have something concrete
to model, and we must learn the concepts to use to express these models, and that is the focus
of this post.

I am going to use the RGen Metamodel Builder API, a Ruby DSL for creation of meta models
to illustrate simply because it is the easiest way to create a model.

### Modeling Process - an example

When we are modeling, we typically produce the model in several iterations - first
just starting loosely with the nouns, verbs, and attributes of our problem domain.
We recently did this exercise for a first version of Puppet's future Catalog Builder, and
it went something like this:

* We need to be able to build a *Catalog*
* A Catalog contains *Resources*
* A Resource describes a wanted state of a particular resource type in terms of *Properties*
* A Resource also describes *Parameters* that are input to the resource provider performing the work
* It would be great if we could define a catalog consisting of multiple catalogs to be applied
  in sequence - maybe *Section* is a good name for this
* While the catalog is built we need to be able to make future references
* We need to track where resources in the catalog originates (they may be virtual and exported from
  elsewhere)
* ... etc.

Once we settled on a handful of statements, we could then whiteboard a tentative model, and reason
about the implications. We continued with all the various sets of requirements, and
we took pictures of the whiteboard, and made some written notes to remember what we did.

Next step was to document this more formally. I used the graphical modeling tool for Eclipse to make a diagram. Using this diagram, we then walked through it, continued discussing / testing use cases, and revising
the diagram. The revised diagram after a couple of iterations looks like this:

CATALOGMODEL.PNG

At this point in the lifecycle of the model, it is fastest to make changes in the graphical tool, and
it is much faster and easier to communicate what the model means than if everything is
written in a programming language. After a while though, it becomes
somewhat tedious to describe all the details in the diagram, and while we can use
the output directly from the tool to get a version in Ruby, we really want
to maintain the original model in Ruby source code form.

We then made an implementation of the model in Ruby that you can [view on github][2].

[2]:https://github.com/hlindberg/puppet/blob/2ae7ec125fdc84535428c83fc07cc9363c7d05b0/lib/puppet/biff/model/catalog.rb

The work of making the diagram and the implementation in Ruby took me something
like 4 hours spread out over the breaks we took while discussing and white-boarding.

We expect to revise this model several times until it is done. If we want
to generate a graph, we can now go in the other direction and create input
to the graphical tool from the code we wrote in Ruby. This is basically a
transformation from the Ruby code to Ecore in XMI since that is what the graphical
tool understands. 

The reason why I included this real life example is to show something that is
relevant to the Puppet community. I am however going to switch
to toy examples to demonstrate the various techniques when modeling
since any real life model tends to overshadow the technique with
domain specific issues - i.e. this post is not about the Catalog-model, it is
about modeling in general.

### Concepts

The basic concepts used when modeling are:

* We model classifiers / **classes**
* Classes have named **features**
* A feature is an **attribute** of a simple data type, or a **relationship** to another class
* Attributes can be **multi valued**
* A relationship can describe **containment**
* A relationship can be **uni-, or bi-directional** (a bi-directional reference allows us
  to conveniently navigate to an object that is "pointing to" the object in question).
* Relationships can be multi valued at one side (or both sides for non containment relationships).
* The term **multiplicity** is sometimes used to denote optional/single/multi-value in
  relationships, e.g. 0:1, 1:1, 0:M, 1:M, or M:M
* An **abstract** class can not be instantiated
* Ecore also contains modeling of *interfaces*, this is mostly useful for Java and I am going to
  skip explaining these.

### Classes

When using RGen's Meta Model Builder, the classes in a model are simply placed in a module
and made to inherit the base class `RGen::MetamodelBuilder::MMBase`. It is common to let each
meta model define an abstract class that signals that it is part of that model.

    require 'rgen/metamodel_builder'

    module MyModel
      # Let RGen know this module is a model
      extend RGen::MetamodelBuilder::ModuleExtension

      # An abstract class that makes it easier to check if a given
      # object is an element of "MyModel"
      #
      class MyModelElement < RGen::MetamodelBuilder::MMBase
        # We make this class abstract to make it impossible to create instances of it
        abstract
      end
  
      class Car < MyModelElement
        # definition of Car
      end
    end
    
At this point we cannot really do much except create an instance of a Car

    require 'mymodel'
    a_car = MyModel::Car.new
    
### Attribute Features

Attribute features are used to define the attributes of the class that are represented by basic
data types. Attributes have a name, a type, and multiplicity. A single value attribute is defined by
calling `has_attr`, a multivalued attribute by calling `has_many_attr`.

The basic data types are:

* `String`
* `Integer`
* `Float`
* `Numeric`
* `Boolean`
* `Enum`

You can also use the completely generic `Object` type, but this also means that the model
cannot be serialized, so this should be avoided. It is also possible to reference implementation
classes, but this should also be avoided for serialization and cross platform reasons.

The `Enum` type can be specified separately, and given a name, or it may be defined inline.

    EngineEnum = RGen::MetamodelBuilder::DataTypes::Enum.new([:combustion, :electric, :hybrid])
    
    class Car < MyModelElement
      has_attr 'engine', EngineEnum
      has_attr 'doors', Integer
      has_attr 'steering_wheel', String
      has_attr 'wheels', Integer
    end
    
If we have an attribute that should be capable of holding many values, we use `has_many_attr`.
In the example below, an enum for extra equipment is used - it does not have
to be an enum, a multi valued attribute can have any basic data type.

    ExtraEquipmentEnum = RGen::MetamodelBuilder::DataTypes::Enum.new([
      :gps, :stereo, :sun_roof, :metallic
    ])
    class Car < MyModelElement
      has_many_attr 'extras', ExtraEquipmentEnum
      # ...
    end
    
The resulting implementation allows us to set and get values.

    a_car = MyModel::Car.new()
    a_car.engine = :combustion
    a_car.extras = [:gps, :sun_roof]
    
For multi-valued attributes, we can add and remove entries

    a_car.addExtras(:metallic)
    a_car.removeExtras(:sun_roof)
    a_car.extras   # => [:gps, :metallic]

If we attempt to assign something of the wrong type, we get an error:

    a_car.addExtras(:catapult_chair)

    => In MyModel::Car : Can not use a Symbol(:catapult_chair) where a
       [:gps,:stereo,:sun_roof,:metallic] is expected
      
We can also specify additional metadata for each attribute, but I will return to that later.
    
### Relationship Features

All non basic data types are handled via references. There are two types of references;
containment, and regular. A containment reference is used when the referenced element
is an integral part of the object - e.g. when it is an attribute of the object, when
something cannot and should not be shared between objects (one particular wheel can
only be mounted on once car at the time), and when they should be serialized as part
of the object that holds the reference. All other references requires that the referenced
object is contained somewhere else (although this is not quite true as we will see later
when we talk about more advanced concepts, it is a reasonable conceptual approximation for now).

In order to have something meaningful to model, lets expand the notion of `Engine`.

    class Engine < MyModelElement
      abstract
    end
    
    FuelTypeEnum = RGen::MetamodelBuilder::DataTypes::Enum.new([:diesel, :petrol, :etanol])

    class CombustionEngine < Engine
      has_attr 'fuel', FuelTypeEnum
    end
    
    class ElectricalEngine < Engine
      has_attr 'charge_time_h', Integer
    end

    # skipping HybridEngine for now
    
### Containment

We can now change the `Car` to contain an `Engine`. When we do this, we must also decide if the `Engine` should explicitly now about which car it is mounted in or not. That is, if the containment
relationship is uni- or bi- directional. Let's start with a uni-directional containment:

    class Car < ModelElement
      contains_one_uni 'engine', Engine
      # ...
    end
    
We can now create and assign an `Engine` to a `Car`.

    a_car = MyModel::Car.new
    a_car.engine = MyModel::CombustionEngine.new
    
If we want to make the containment bi-directional:

    class Car < MyModelElement
      contains_one 'engine', Engine, 'in_car'
      # ...
    end

The assignment works as before, but we can now also navigate to the car the engine is mounted
in. We achieved this, by defining the reverse role 'in_car' for the bi-directional containment.
Now we can do this:

    an_engine = MyModel::CombustionEngine.new
    an_engine.in_car            # => nil
    a_car = MyModel::Car.new
    a_car.engine = an_engine
    an_engine.in_car            # => Car
   
The semantics of containment means that if we assign the engine to another car we will **move it**!

    # continued from previous example
    another_car = MyModel::Car.new
    a_car.engine                # => CombustionEngine
    another_car.engine = engine
    another_car.engine          # => CombustionEngine
    a_car.engine                # => nil
    
This may seem scary, but it is actually quite natural. If we find that we want to contain something
in more than one place at a given time our model (and thinking) is just wrong, and one of
the references should not be a containment reference. Say if we have a `ServiceOrder` (imagine
for the purpose of repairing an engine), the engine is not ever contained in the order (it is
still mounted in the car). Model-wise we simply use a non-containment / regular reference from
the `ServiceOrder` to an `Engine`.

We specify different kinds of containment with the methods:

* `contains_one`
* `contains_many`
* `contains_one_uni`
* `contains_many_uni`

### Regular References

Regular references are defined with one of the methods:

* `has_one`, uni-directional 
* `has_many`, uni-directional
* `one_to_many`, bi-directional
* `many_to_one`, bi-directional
* `many_to_many`, bi-directional

We can now define a ServiceOrder for service of engines:

    class ServiceOrder < MyModelElement
      has_one 'serviced_engine', Engine
    end

And we can use this:

    an_engine = MyModel::CombustionEngine.new
    a_car = MyModel::Car.new
    a_car.engine = an_engine
    a_car.engine                   # => CombustionEngine
    so = MyModel.ServiceOrder.new
    so.serviced_engine = an_engine
    a_car.engine                   # => CombustionEngine
    
As you can see, since the relationship is non-containment, the engine does not move to
become an integral part of the service order, it is still mounted in the car (which exactly
what we wanted).

For the bi-directional references, the reverse role is required. When using these, it
is important to consider the cohesion of the system - we do not want every piece to
know about everything else. Therefore, choose bi-directional references only where it
really matters.

### Testing the examples

You can easily try the [examples in this gist][3]. You need to have the `rgen` gem installed, and
then you can run the examples in irb, and try things out.

[3]:https://gist.github.com/hlindberg/11406430

### In this Post

In this post you have seen examples of how to build a model with RGen, and how it can be used.
As you probably have noticed, you get quite a lot of functionality with only a small amount of work.
How much code would you have to write to correctly support fully typed many to many relationships?
(And then discover that is not at all what you wanted).

I hope this post has showed the usefulness of modeling even when no fancy modeling tricks
have been used simply because of the robust, type and referentially safe implementation that we
get from a small an concise definition.
