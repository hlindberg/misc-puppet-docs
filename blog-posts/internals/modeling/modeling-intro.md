As you probably know, Puppet creates a Declarative Catalog that describes the desired system
state of a machine. This means that Puppet is actually Model Driven. 
The model in this case is the catalog and the descriptions of the desired state
of a set of resources that is built by Puppet from the instructions given to it
in the Puppet Programming Language.

While Puppet has always been based on this model, it has not been built using modeling technology.
What is new in the future parser and evaluator features in Puppet is that we have started using modeling technology to also implement how Puppet itself works.

In this post, I am going to talk a bit about modeling in general, the Ecore modeling technology
and the Ruby implementation of Ecore called RGen.

### What is a "model" really?

If at first when you hear the word *model*, you think about Tyra Banks or Marcus Schenkenberg and then laugh a little because that is obviously not the kind of models we are talking about here. You are actually not far off the mark.

A model is just an abstraction, and we use them all the time - they are the essence of any spoken language; when we talk about something like a "Car" we are talking about an unspecific instance of something like "a powered means of transportation, probably a 4 door sedan". Since it is not very efficient to communicate in that way, we use the abstraction "Car". Fashion models such as Tyra or Marcus are also abstractions of "people wearing clothes" albeit very good looking ones (perhaps you think they represent "people that do not wear enough clothes", but they are still abstractions).

We can express a model concretely using natural language:

    A Car has an engine, 2 to 5 doors, a steering wheel, breaks, and 3-4 wheels.
    . . .
    
We can also express such a model in a programming language such as Ruby:

    class Car
      attr_accessor :engine
      attr_accessor :doors
      attr_accessor :steering_wheel
      attr_accessor :breaks
      attr_accessor :wheels
      
    . . .
    end

As you can see in the above attempt to model a `Car` we lack the semantics in Ruby to declare
more details about the Car's attributes - there is no way to declaratively state 
how many doors there could be, the number of wheels etc. There is also no way to declare
that the `engine` attribute must be of `Engine` type, etc. All such details must be implemented 
as logic in the setter and getter methods that manipulate a Car instance. While this is fine
from a runtime perspective (it protects us from mistakes when using the class), we can not
(at least not easily) introspect the class and deduce the number of allowed doors, or the allowed type of the various attributes.

Introspection (or reflection) is the ability to programmatically obtain information about
the expressed logic. Sometimes we talk about this as the ability to get meta-data (data about
data) that describes what we are interested in.

While Ruby is a very fluid implementation language, in itself it is not very good at
expressing a model.

### Modeling Language

A modeling language (in contrast to an implementation language such as Ruby) lets us
describe far more details about the abstraction without having to express them in imperative
code in one particular implementation language.
One such family of "languages" are those that are used to describe data formats - they
are referred to a *schemas* - and you are probably familiar with some of them such as XmlSchema,
JsonSchema, and Yamlschema. These schema technologies allows us to make declarations about what is allowed in data that conforms to the schema and we can use this to validate actual data.

A schema is a form of modeling language. What is interesting about them is that they enable
transformation from one form to another! Given an XmlSchema, it is possible to transform it
into a corresponding Yaml or Json schema, and likewise transform data conformant with one such
schema into data conformant with the transformed schema.
(The problems doing this in practice has to do with the difference in semantic power between the different technologies - we may be able to express rules/constraints in one such schema technology that does not exist the others).

### Schemas and Meta Models

When we look at a schema - we are actually looking at a *meta model*; a model that describes a model.
That is if we describe a Car in Json we have a **Car model**:

    { "engine": "combustion",
      "steering-wheel": "sport-leather",
      "wheels": ...
    }
    
And if we describe a schema for it:

    { "title": "Car Schema",
      "type"; "object",
      "properties": {
        "engine": { "type": "string"},
        "steering-wheel": { "type": "string" },
        . . .
      }
      "required": ["engine", "steering-wheel", ...]
    }
    
We have a **Car meta-model**.

In everyday speak, we typically refer to the schema as "schema" or "model" and simply ignore
its "meta status". But since we are on the topic of meta models - what we can do now is to
also express the meta model as a model - i.e. what is the schema for a jsonschema?
Here is an excerpt from the [Json "Core/Validation Meta-Schema"][1]

    {
      "id": "http://json-schema.org/draft-04/schema#",
      "$schema": "http://json-schema.org/draft-04/schema#",
      . . .
       "title": {
            "type": "string"
        },
      . . .
      "required": { "$ref": "#/definitions/stringArray" },
      . . .
    }

If you are interested in what it looks like, do download it. Be warned that you will quickly become
somewhat disoriented since it is a schema describing a schema that describes what Json data
should look like...

[1]:http://json-schema.org/documentation.html

A meta schema such as that for JsonSchema is very useful as it can be used to validate schemas
that describe data.

Schemas such as XmlSchema, YamlSchema, and JsonSchema are good for describing data, but they
becomes somewhat difficult to use in practice for the construction of software. There are other modeling languages that are more specifically targeting software system constructs. There are both graphical and textual languages as well as those that have both types of representations.

What we are specifically interested in is an [Object modeling language][2], which I will explain in more details.

[2]:http://en.wikipedia.org/wiki/Object_modeling_language

### Levels of reality / meta-ness

We can organize what we just learned about a model and its relationship to a meta-model, and that all of these can be expressed as a model. Here is a table that illustrates this from most concrete to most abstract:

| Meta-Level | Description |
| --- | --- |
| M0 | Real Object - e.g. the movie "Casablanca on a DVD" |
| M1 | User Model / Instance Level - e.g. a computer abstraction of the DVD - `aVideo = Video.new('Casablanca')` |
| M2 | Meta Model - e.g. defines what `Video` is, its attributes and operations |
| M3 | Meta meta model - e.g. defines how the definition of "what a `Video` is", is expressed |

We very rarely talk about meta-meta models (this is the technology we use to implement a meta-model), and we also typically leave out the meta word when talking about a meta-model (i.e. just using the word model). We also typically talk about an "instance of a model" as being just a "model", without any distinction about its form; as live objects in memory that we can manipulate, or serialized to disk, stored in a database etc. It is only when we talk explicitly about modeling and modeling technology that we need to use the more precise terms, most of the time, it is perfectly clear what we are referring to when we use the word "model".

### Object Modeling Language

An Object Modeling Language is a language that directly supports the kinds of elements we are interested in when constructing software. E.g. classes, methods, the properties of objects. You probably heard of one such technology called [UML - Unified Modeling Language][3] - this is a broad modeling technology and is associated with object oriented software development methodologies such as Booch, OMT, Objectory, IBM's RUP, and the Dynamic Systems Development Method. This was The Big Thing in the 90's, but UML has since then more or less slid into darkness as "the way to write better
software" has shifted focus. An interesting debate from 2009, can be found [here][4].

[3]:http://en.wikipedia.org/wiki/Unified_Modeling_Language
[4]:http://codebetter.com/jeremymiller/2009/09/12/how-relevant-is-uml-modeling-today/

There is however a very useful part of the UML technology that is often overlooked - the so
called Meta Object Facility (MOF) that sits at the very core of UML. It contains the (meta-meta) model that UML itself is defined in. MOF plays the same role for models as what Extended Backus Naur Form (EBNF) plays for programming languages - it defines the grammar. Thus MOF can be said to be a domain specific language used to define meta models. The technology used in MOF is called **Ecore** - and it is the reference implementation of MOF. (It is a model at level M3 in the table above).

### Ecore

Ecore is part of [Eclipse EMF][5], and is heavily used within Eclipse for a wide variety of
IDE applications and application development domains. In the Puppet Domain EMF/Ecore technology is
used in the [Puppetlabs Geppetto IDE][7] tool in combination with additional frameworks for language development such as [Xtext][6].

[5]:http://en.wikipedia.org/wiki/Eclipse_Modeling_Framework
[6]:http://en.wikipedia.org/wiki/Xtext
[7]:http://puppetlabs.github.io/geppetto/
[8]:https://github.com/mthiede/rgen
[9]:https://code.google.com/p/emf4cpp/

Eclipse EMF is a Java centric implementation of Ecore. There are also implementations for
Ruby ([RGen][8], and C++ [EMF4CPP][9]).

Thus, there are many different ways to express an Ecore model. The UML MOF has defined one
serialization format known as XMI, which is based on XML, but there are many other concrete
formats such as Xcore (a DSL built with Xtext, annotated Java, JSon, binary serialization formats, 
the Rgen DSL in Ruby, etc.)

### Car in RGen

Here is the Car expressed with RGen's MetamodelBuilder. In the next blog post about modeling I will talk a lot more about RGen - this is just a simple illustration:

    class Car < RGen::MetamodelBuilder::MMBase
      has_attr 'engine', DataTypes::Enum.new([:combustion, :electric, :hybrid])
      has_attr 'doors', Integer
      has_attr 'steering_wheel', String
      has_attr 'wheels', Integer
      
    . . .
    end

A few points though:

* `RGen::MetamodelBuilder::MMBase` is the base class for all models implemented with
  RGen (irrespective of how they are defined; using the metamodel builder, using the API directly, 
  loading an ecore XMI  file, or any other serialization format).
* `has_attr` is similar to Ruby's `attr_accessor`, but it also specifies the type and type checking
  is automatic.
* You can probably guess what `Enum` does

If you are eager to see real RGen models as they are used in Puppet, you can take a look at the [AST model][10], or the [type model][11].

[10]:https://github.com/puppetlabs/puppet/blob/master/lib/puppet/pops/model/model.rb
[11]:https://github.com/puppetlabs/puppet/blob/master/lib/puppet/pops/types/types.rb

### Benefits of Modeling Technology

So what is it that is appealing about using modeling technology?

* The model is declarative, and can often be free of implementation concerns
* Polyglot - a model can be used dynamically in different runtimes, or be used to generate
  code.
* Automatic type checking
* Support for containment and serialization
* Models can be navigated
* Objects in the model has information (meta-data) about where they are contained ("this is the left
  front wheel of the car XYZ 123").
* Direct support for relationships, including many to many, and bidirectional relationships

Which I guess boils down to is that "Modeling technology removes the need to write a lot of boilerplate code"
In the following posts I will talk about these various benefits and concepts of Ecore using examples in RGen.


### In this Blog Post

In this blog post I explained that a model is an abstraction, and how such an abstraction can be implemented in software i.e. hand written, or using modeling technology such as Data Schemas or
one specifically designed for software such as Ecore which available for Ruby in the form of the RGen gem. I also dived into the somewhat mysterious domain of meta-meta models - the grammar used to describe a meta-model, which in turn describes something that we want be manipulate/ work with in
our system.

Things will be more concrete in the next post, I promise.

