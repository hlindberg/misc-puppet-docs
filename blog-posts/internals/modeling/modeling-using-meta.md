In this post about modeling with Ecore and RGen I will explain the operations that allows us to navigate the model, and how to generically get and set elements / values in the model, as well as how 
to get to the meta-model from model objects.

### e-ness

As you will see, methods that operate on, or make use of Ecore meta data are typically named
with an initial lower case *'e'*. They also use Camel Cased names to make these operations as similar as possible to the corresponding operations in EMF / Java. Whenever you see such 'e' methods, they are about the Ecore aspects of the object (instance), or its class (access to the meta-model). In everyday speak we can talk about this as the object's *e-ness* (since it is much easier to say than "the meta aspects of..."

In this post I will show the various basic 'e' operations with examples. If you want to
get the source of the model used in the examples, the final version is available in [this gist][2].

### Getting Content

One of the first things you typically want to do is to get the content of a model generically
(that is, without any explicit knowledge about a particular model).

First, we need to make a couple of adjustments to the example model I showed in the [previous post][1]. RGen comes with some built in navigations, but not all that are available in the EMF (Java) implementation of Ecore. So, we have a module in Puppet that should be included to get
full support.

We need to add:

    require 'puppet'
    require 'puppet/pops'

And then in our base class (that all our domain model classes inherit form) define it like this:

    class MyModelElement < RGen::MetamodelBuilder::MMBase
      include Puppet::Pops::Containment
      abstract
    end

### Getting All Contents

A common operation is to iterate over all containments in an object. This is done with the method `eAllContents` which is typically called with a block receiving each **contained** element.
It can also be called without a block to get a Ruby `Enumerable`.

The `eAllContents` method does not include the object it is invoked on, only its content is included
in the enumeration. It visits all contained recursively in depth first order where parents appear
before children.

We can try this out with the Car model. 

    engine = MyModel::CombustionEngine.new
    car = MyModel::Car.new
    car.engine = engine
    
    car.eAllContents.map {|element| "#{element}" }
    
    # => ["#<MyModel::CombustionEngine:0x007ff8a1b606d8>"]
    
In the Puppet implementation of the future parer, the ability to iterate over all contents is
used when validating models. In particular the model produced by the parser. 

### Getting All Containers

If we have a model element, and would like to traverse all of its containers (until we reach the
root) we use the `eAllContainers`. If we just want the immediate container we use `eContainer`.

    # continuation of the previous example
    engine.eContainer                       # MyModel::Car
    engine.eAllContainers.to_a              # [MyModel::Car]

Not so exiting, but if we add a `Garage` that can contain cars - i.e. by adding this to the model:

    class Garage < MyModelElement
      contains_many_uni 'cars', Car
    end

And then add our car to the garage.

    garage = MyModel::Garage.new
    garage.addCars(car)
    engine.eAllContainers.to_a              # [MyModel::Car, MyModel::Garage]

    # and just to check what happens if we get all contents in the garage
    garage.eAllContents.to_a                # [MyModel::Car, MyModel::CombustionEngine]
    
In the Puppet implementation of the future parser, the ability to search up the containment
chain is used in validation (some object must be contained by top level constructs), and
in order to find information such as a source text location index, and to find the loader that
loaded the code (which is recorded at the root of the model).

#### Where am I? What is my role?

It is often useful to ask:

* Where is this object contained?
* What is this object's role in that container?

In the sample car model we have right now, this is not so valuable, since we do not have anything 
that can be contained in multiple places. So to make this a bit more interesting we can add the
following to the model

    class Car < MyModelElement
      # as before AND...
      has_attr 'reg_nbr', String, :defaultValueLiteral => 'UNREGISTERED'
      contains_one_uni 'left_front', Wheel
      contains_one_uni 'right_front', Wheel
      contains_one_uni 'left_rear', Wheel
      contains_one_uni, 'right_rear', Wheel
    end
    
    RimTypeEnum = RGen::MetamodelBuilder::DataTypes::Enum.new([:black, :silver])

    class Wheel < MyModelElement
      has_attr 'rim', RimTypeEnum
      has_attr 'rim_serial', String
    end 
   
The above example also shows how to set a default value for an attribute. Default values
can only be used with single valued attributes. All other have an empty `Array` as their default.

Now we can create wheels and assign to the car. This also demonstrates that it is possible
to give values to features in a `Hash` when creating the instance:
  
    car = MyModel::Car.new(:reg_nbr => 'ABC123')
    car.left_front  = w1 = MyModel::Wheel.new(:rim_serial => '1', :rim => :silver)
    car.right_front = w2 = MyModel::Wheel.new(:rim_serial => '2', :rim => :silver)
    car.left_rear   = w3 = MyModel::Wheel.new(:rim_serial => '3', :rim => :silver)
    car.right_rear  = w4 = MyModel::Wheel.new(:rim_serial => '4', :rim => :silver)

And now we can start asking questions:

    w1.eContainer.reg_nbr    # => 'ABC123'
    w1.eContainingFeature    # => :left_front
    w2.eContainer.reg_nbr    # => 'ABC123'
    w2.eContainingFeature    # => :right_front
    
In the Puppet implementation this operations are typically used when generating error messages.
An error is found in some deeply nested / contained element and a message should inform the
user about where it is being used / the role it plays. Sometimes also used in validation when
something is valid or not depending on the role it plays in its container.

### Generic Get

Features can be read generically with the method `getGeneric`. Using the wheel example above:

    car.getGeneric(:left_front).rim_serial  # => '1'
    w1.getGeneric(:rim)                     # => :silver

There is also a `getGenericAsArray` which returns the value in an `Array`, if it is not already
one (which it always is when the feature is multi-valued).

The method `eIsSet` can be used to test if a feature has been set. This returns `true` if
the value has any other value than the feature's default value (and if default value is not
defined, if the feature is nil).

    car2 = MyModel::Car.new
    car2.reg_nbr                 # => 'UNREGISTERED'
    car2.eIsSet(:reg_nbr)        # => false
    car2.reg_nbr = 'XYZ123'
    car2.eIsSet(:reg_nbr)        # => true
    
This means we can define the value that represents "missing value" per single valued feature, and
as you will see below we can reset the value to the default.

At present we do not use this anywhere in the implementation as the validation logic is
aware of the individual classes. We may make use of it to add additional generic validation that
is driven by meta data alone. We will probably also use this when we get to the catalog and resource
type models.

### Generic Mutating Operations

As you may have guessed, it is also possible to generically modify objects. The methods are:

* `setGeneric(name, value)`
* `addGeneric(name, value)`
* `removeGeneric(name, value)`
* `eUnset(name)` - sets feature to its default value (or nil/empty list if there is no default)

Here is an example using `eUnset` to return the car to the default for its `reg_nbr`:

    carxyz123 = MyModel::Car.new(:reg_nbr => 'XYZ123')
    carxyz123.eIsSet(:reg_nbr)                          # => true
    carxyz.reg_nbr                                      # => 'XYZ123'
    carxyz.eUnset(:reg_nbr)
    carxyz123.eIsSet(:reg_nbr)                          # => false
    carxyz.reg_nbr                                      # => 'UNREGISTERED'
        
### So, what is missing from the picture?

You may have noticed it already. We did add an `eAllContents`, and `eAllContainers` to each
model class by including the `Puppet::Pops::Containment` module, but these only operate on
containment references. 

* How can you get all features including attributes and regular references?
* Why are these not directly available on all model objects as individual methods?

The reasons for the design are that it is very common to navigate to the container, or to contained children e.g. for validation purposes, but these operations typically result ending up in logic that has specific knowledge about a particular class, and there we are in a context where we already know about all of the attributes and references and we can just use them directly.

While it would be possible to provide direct access to almost all e-ness methods directly, there is a limit to how much bloat we want in each class. Therefore, there rest of the operations we may want to 
perform has to use a slightly more round-about (and completely generic) way of getting to the information via information in the meta-model.

All the information we need is available in the meta-model, and the following sections
will show how we can make use of this.

### Getting the Meta Model

We can get the entire meta-model from the Ruby module by calling the method `ecore`:

    MyModel.ecore                  # => ECore::EPackage

From there we can navigate the contents of the entire package. As an example, one of
the methods, `eAllClasses`, gives us all defined classes. Here is what happens if you
try this in `rib` on `MyModel` (we map to each class' name to get something that is meaningful
as output):

     MyModel.ecore.eAllClasses.map {|ec| ec.name }
     => ["MyModelElement", "Engine", "CombustionEngine", "ElectricalEngine", "Car",
         "ServiceOrder", "Garage", "Wheel"]

   
We can also get to the meta model element for each individual class in our model by calling the 
method `ecore` on the object's class. (We can not use this on the values of attributes since
they are basic Ruby types, and thus do not have any *e-ness*).

    car = MyModel::Car.new
    car.class.ecore               # => RGen::ECore::EClass
    
Oh, look we got something back called an `EClass` which is the meta-model representation of a class.
The `EClass` has many useful methods to get information about the class, its attributes, references,
containments etc. As an example, the method `eAllAttributes` returns an `Enumerable` with `ECore::EAttribute` elements that describes all of the attributes for the class and all of its superclasses.

If you thought it just started to get interesting, don't worry, I will come back with more about about the `ECore` model in the next post.

### In this Post

In this post you have seen how a model can be navigated, and how we can find the meta-data for elements in the model. In the next post I am going to dive deeper into the Ecore model itself.


[1]:http://puppet-on-the-edge.blogspot.se/2014/04/puppet-internals-basic-modeling-with.html
[2]:https://gist.github.com/hlindberg/7fae2744d9a7266139fd