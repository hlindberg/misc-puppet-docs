### Serialize and Deserialize a Model to/from JSon

To serialize a model to JSon we can use one of the serializer that comes with RGen. Here is
an example using the [Car Model][1] developed in previous posts in this series.

    require 'rgen/environment'
    require 'rgen/serializer/json_serializer'
    require 'rgen/instantiator/json_instantiator'

    # Define a simple String output Writer instead of using IO to a file
    class StringWriter < String
      alias write concat
    end

    # POPULATE
    # ---
    car1 = MyModel::Car.new(:reg_nbr => 'ABC 123')
    car2 = MyModel::Car.new(:reg_nbr => 'XYZ 123')
    garage = MyModel::Garage.new
    garage.addCars(car1)
    garage.addCars(car2)
    
    # SERIALIZE
    # ---
    output = StringWriter.new
    serializer = RGen::Serializer::JsonSerializer.new(output)
    
    # We wrap the garage in an Array to make it easier to find it when deserializing
    serializer.serialize([garage])
    
    # DESERIALIZE
    # ---
    modeling_env = RGen::Environment.new
    instantiator = RGen::Instantiator::JsonInstantiator.new(modeling_env, MyModel)
    model_roots = []
    unresolved = instantiator.instantiate(output, :root_elements => model_roots)

    # WHAT DID WE GET
    # ---
    root = model_roots[0]
    root.is_a?(MyModel::Garage)    # => true
    root.cars.map {|c| c.reg_nbr } # => ['ABC 123', 'XYZ 123']
    

As you can see, serialization is trivial. We can serialize anything, a single model object (and all that it contains), or an array of objects. When we use an array we can get that array back again when deserializing. This is convenient as we would otherwise have to go on a hunt for the object we consider to be the root object in our model.

Deserialization is a bit more involved since we need to keep track of what has been serialized
to be able to resolve references. We also need to give the deserializer a meta-model so it
know what it is it is deserializing. 

As you also see, in the call to instantiate, we pass in an empty array as an option. This
array will be filled with the root objects from the JSon deserialization. (This is the reason
we placed the garage in an Array when we serialized). If we did not do this, we would need
to search for the garage object we are interested in using one of the methods on the `RGen::Environment` as shown in the next section.

### The RGen::Environment

The `RGen::Environment` object that we passed in to the instantiator is used as a container 
of everything that is deserialized for the purpose of resolving references. After deserialization
we can get all elements from it, and we can use find to search for an element.

The elements method simply returns all content in an Array:

    modeling_env.elements   # => [MyModel::Garage, MyModel::Car, MyModel::Car]
    
The find method can find classes, or objects that return a particular value from
a given method.

    found_cars = modeling_env.find(:reg_nbr => 'ABC 123')

If we have multiple things that have an attribute called `reg_nbr`, we can limit the search
to a particular class, or an `Array` of classes like this:

    found_cars = model_env.find(:class => MyModel::Car, :reg_nbr => 'ABC 123')

    