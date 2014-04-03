Puppet is a model driven system - a desired system state is modeled by describing the
desired state of a set of resources, these are compiled into a catalog, and the catalog is
applied to a system to make it have the desired modeled state.

What is new in the "future parser/evaluator" features in Puppet is that we started using modeling technology to implement how puppet itself works.

In this post, I am going to talk a bit about modeling in general, the Ecore modeling technology
and the RGen Ruby implementation of Ecore.

### What is a "model" really?

If at first when you hear the word *model*, you think about Tyra Banks or Marcus Schenkenberg and then laugh a little because that is obviously not the kind of models we are talking about here, you are actually both right and wrong at the same time.

A model is an abstraction. We use abstractions all the time; when we talk about something like a "Car" we are talking about an unspecific instance of something like "a powered means of transportation, probably a 4 door sedan". Fashion models such as Tyra or Marcus are also abstractions of "people wearing clothes" albeit very good looking ones - in a way like if we design a Car icon to depict a Lamborghini, but now I am beginning to get off topic and into a completely different debate.

We can express a model concretely:

    A Car has an engine, 2 to 5 doors, a steering wheel, breaks, and 4 wheels.
    . . .
    
We can also express such a model in a programming language:

    class Car
      attr_accessor :engine
      attr_accessor :doors
      attr_accessor :steering_wheel
      attr_accessor :breaks
      attr_accessor :wheels
      
    . . .
    end

As you can see in the above attempt to model a Car we lack the semantics in Ruby to declare
more details about the Car's attributes - there is no way to declaratively state 
how many doors there could be, the number of wheels etc. There is also no way to declare
that the engine attribute must be of engine type, etc. All such details must be implemented 
as logic in the setter and getter methods that manipulate a Car instance. While this is fine
from a runtime perspective (it protects us from mistakes when using the class), we can not
(at least not easily) introspect the class and deduce the number of allowed doors, or the allowed type of the various attributes.

While Ruby is a very fluid implementation language, in itself it is not very good at
expressing a model.

### Modeling Language

A modeling language (in contrast to an implementation language such as Ruby) lets us
describe far more details about the abstraction without having to express them in imperative
code. One such family of "languages" are those that are used to describe data formats - they
are referred to a schemas - and you are probably familiar with XmlSchema, JsonSchema, Yamlschema etc
that allows a declaration to be made about what is allowed in data that conforms to the schema.

A schema is a form of modeling language. What is interesting about them is that it now possible
to transform between them! Given an XmlSchema, it is possible to transform it into a corresponding
Yaml or JsonSchema, and likewise transform data conformant with one such schema into data comformant
with the transformed schema. (The problems doing this in practice has to do with the difference in semantic power between the different technologies - we may be able to express rules/constraints
in one such schema technology that does not exist the others).

### Schemas and Meta Models

When we look at a schema - we are actually looking at a meta model; a model that describes a model.
That is if we describe a car in Json we have a car model:

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
    
We have a Car meta-model.

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

A meta schema such as that for jsonschema is very useful as it can be used to validate schemas
that describe data.

Schemas such as these are good for describing data, but they becomes somewhat difficult to use
in practice for the construction of software. There are other modeling languages that are more specifically targeting software system constructs. There are both graphical and textual languages
as well as those that have both types of representations.

What we are specifically interested in is an [Object modeling language][2]

[2]:http://en.wikipedia.org/wiki/Object_modeling_language

### Levels of reality / meta-ness

| level | Description |
| --- | --- |
| M0 | Real Object - e.g. the movie Casablance on a DVD |
| M1 | User Model / Instance Level - e.g. a computer abstraction of the DVD - `aVideo = Video.new('Casablanca')` |
| M2 | Meta Model - e.g. defines what `Video` is, its attributes and operations |
| M3 | Meta meta model - e.g. defines how the definition of what a `Video` is, is expressed |


### Object Modeling Language

An Object Modeling Language is a language that directly supports the kinds of elements we are interested in when constructing software. E.g. classes, methods, the properties of objects, etc. You probably heard of one such technology called [Unified Modeling Language][3] - this is a broad modeling technology and is associated with object oriented software development methodologies such as Booch, OMT, Objectory, IBM's RUP, and Dynamic Systems Development Method. This was the big thing in the 90's, but UML has since then more or less slid into darkness as "the way to write better
software". An interesting debate from 2009, can be found [here][4].

[3]:http://en.wikipedia.org/wiki/Unified_Modeling_Language
[4]:http://codebetter.com/jeremymiller/2009/09/12/how-relevant-is-uml-modeling-today/

There is however a very useful part of the UML technology that is often overlooked - the so
called Meta Object Facility (MOF) that sits at the very core of UML and it contains the meta model
that UML itself is defined in. MOF plays the same role for models as what Extended Backus Naur Form (EBNF) plays for programming languages - it defines the grammar. Thus MOF can be said to be a DSL used to define meta models. The technology used in MOF is called Ecore - it is the reference implementation of MOF.

### Ecore

Ecore is part of [Eclipse EMF][5], and is heavily used within Eclipse for a wide variety of
IDE applications and application development domains. In the Puppet Domain Ecore technology is
used in the [Puppetlabs Geppetto IDE][7] tool in combination with additional frameworks for language development [Xtext][6]

[5]:http://en.wikipedia.org/wiki/Eclipse_Modeling_Framework
[6]:http://en.wikipedia.org/wiki/Xtext
[7]:http://puppetlabs.github.io/geppetto/
[8]:https://github.com/mthiede/rgen
[9]:https://code.google.com/p/emf4cpp/

Eclipse EMF is a Java centric implementation of Ecore. There are also implementations for
Ruby ([RGen][8], and C++ [EMF4CPP][9]).

Thus, there are many different ways to express an Ecore model. The UML MOF has defined one
serialization format known as XMI based on XML, but there are many other concrete formats such
as Xcore (a DSL built with Xtext, annotated Java, Json, binary serialization formats, the Rgen score
DSL in Ruby, etc.) 

