ARM-7 Puppet Types - Revisited
===
Now that the Puppet Programming Language Type System has been implemented, it is possible
to revise and simplify the ARM-7 proposal for how to support creation of additional
types - both simple data types and complex types like Puppet Resources.

Coupled to this is also the idea that it should be possible to define functions in
the language. So, lets start with functions.

### Functions

A function can be defined in Puppet using the keyword `func`. The syntax follows that
of other constructs.

    FunctionDefinitionExpression
       : 'function' name = QualifiedReference ( '(' parameters=Parameters ')')? body = Block
       ;

    Parameters
       : params += Param (',' params += Param)*
       ;

    Param
       : params += '$' NAME ('=' Expression)?
       ;
          
    Block
       : '{' statements += Statements '}'
       ;
       
This also supports passing a lambda as the last argument. (We need a type for Lambda)


#### Type Functions

For the definition of types, it is important to be able to define logic for (primarily
three things) - special set/get logic, and for checking validity. These could be defined
as closures/lambdas, but the syntax is not as nice, and it is not that easy to read.

If we instead allow functions to be defined inside of a type, they become methods that
are associated with instances of the type. Another term for the same thing is "type function".

    type user {
      attr password, String {
        def check { if $it =~ /:/ { "A ':' is not allowed in a password" }
      }
      
      attr password_max_age, Integer[0]
      
      attr groups, String {
        $min = 0
        $max = unbound
        $unsettable = true

        function check {
          if $it =~ /:/ { "Use group names not GID. '${it}' not acceptable as group name." }
        }
        
      has roles, UserRole {
        $max = unbound # min 0 implied
      }
    }
    
    type user_role {
      attr gid, String {
        def check { if $it =~ /\d/ { "gid must be non-numeric. '$gid' not acceptable." } }
      }
    }
    
### min/max and base type

Since the base type may express that the value is an array, the min and max can be set
more easily that way. (Setting these via variables have higher precedence).

    # groups is an array of 0 or unbound number of non empty String
    attr groups, Array[String[1], 0, default]
    
Attributes also have these type parameters:

* unsettable - can be set to a state that means "unset" (Requires an operation to unset though,
  which is currently not defined how to invoke). The idea is that unsetting returns an attribute
  to its default and thus does not need to be included in a serialization).
* derived - a computed value, is by default also transient and virtual
* settable - attribute can be set
* transient - never included in serialization
* virtual - has no storage/state
* default - default value, always in the data type's string form

These are set via variable expressions.

### Mapping to Ecore

Each base type has a defined mapping to how it is represented in Ecore. How this is
done is obvious for `Boolean`, `Integer`, `String`, and `Float`, and also quite obvious for
`Enum`. Other types requires additional mapping.

* Well, ecore `Enum` needs one small nudge, it uses Symbol values, and we need a mapping to String

* `Array[T]` - this translates to a multi valued attribute of T, where the Array's size constraint
  defines the constraint of the multiplicity. If the `T` is not expressible directly in Ecore we
  need to handle it differently (see below).
  
* `Hash[K,V]`, `Struct[{...}]` - This requires an intermediate type that defines the `K,V`
  pair. We can
  choose not to support this in favor of user defined mapping to explicitly types - but that is
  probably not going to be popular.

Certain types are even more difficult to handle since they may represent disjunct types.

    Variant[String, Integer]
    Tuple[String, Integer]
    Struct[{a=>String, b=>Integer}]
    
Problems extend to those types that include them - i.e. `Array[Variant[S, T, U]]`, etc.

This is a problem because this can not be expressed with a regular attribute since it
requires one base type (and in this case that is `Scalar`, and the modeling technology does not
allow this). The same problem occurs when storing instances of the model in a database table,
when querying etc.

There are two main solutions to this problem:

* We do not support it and users have to explicitly define all types beyond generic `Array`
* We automatically map the constructs using anonymous intermediate types

The first option is easy to implement :-), but the second requires a bit more thought
and effort. This is explored below to be able to discuss if it should be done or not.

One way to model disjunct attributes is to define one type that is a union of the scalar types
(and union itself), all with 0-many multiplicity - i.e.

    class DataUnion {
      has_many_attr int, Integer
      has_many_attr str, String
      has_many_attr bool, Boolean
      has_many_attr float, Float
      contains_many unions, DataUnion
    }
    
A discriminator can also be added to avoid having to search for the one non-nil value. This
discriminator could be a reference to the corresponding score data type (`EInteger`, `EString`, etc),
but it is then difficult to handle the union type which has no `E` equivalence. Instead, the
discriminator is a reference to its Puppet Type.

    class DataUnion {
      has_one type, PAbsractType
      has_many_attr int, Integer
      has_many_attr str, String
      has_many_attr bool, Boolean
      has_many_attr float, Float
      contains_many_uni unions, DataUnion
    }

    
Thus a declaration like this:

    type mytype {
      attr whatever, Variant[String, Integer]
    }
    
is translated to ecore

    class mytype {
      contains_one_uni whatever, DataUnion do
        annotation 'puppet_type' => 'Variant[String, Integer]'
      end
      
      # methods to set/get and validate are not shown
      }

We use the ecore annotation system to store additional meta data in the model. The Puppet
Type system can represent types as String, and generic logic can handle the transformation
to a type, generic logic can handle setting and getting values etc. The annotations are
stored in the ecore model and can be picked up at runtime. Generators for other languages
will have to be customized to generate the correct code - structures can be serialized and
deserialized in all cases, but for validation to work, an implementation of the type system
is also required.

For a Hash with concrete, generic type it is possible to optimize and generate an entry
type for each unique K/V combination. Thus, with this input:

    type mytype {
      attr my_hash, Hash[String, Integer]
    }
   
We could translate it to ecore like this:

    class MyType {
      contains_one_uni my_hash, DataHash do
        annotation 'puppet_type' => 'Hash[String, Integer]'
      end
      
      # methods to set/get and validate are not shown
      }

    # These two classes are generic hashes used by all
    class DataHash {
      contains_many_uni hash_entries, DataHashEntry
    }

    class DataHashEntry {
      contains_one_uni key, DataUnion
      contains_one_uni value, DataUnion
    }
    
Now, we also need to update the `DataUnion` ecore type:

    class DataUnion {
      has_one type, PAbsractType
      has_many_attr int, Integer
      has_many_attr str, String
      has_many_attr bool, Boolean
      has_many_attr float, Float
      contains_many_uni unions, DataUnion
      contains_many_uni hashes, DataHash
    }
 
Needless to say, this creates a bit of overhead and users should be encouraged to always
explicitly define types as this is both more performant and easier to use throughout the
system. (In contrast it may be perceived as easier to work with anonymous hashes and structs
in puppet code)

### Simple Data Type

Some types are just named parameterized types. E.g.

    type ip_address inherits Pattern[/..../]
    
This allows the type Ip_address to be used instead of repeating `Pattern[/.../]`. This is
especially useful for `Enum`, `Tuple`, and `Struct`.

In essence, such a declaration is just an alias.

### Type Syntax

    TypeDefinition
      : 'type' name = NAME ('inherits' Expression<PAbstractType>) body = TypeBody?
      ;
      
    TypeBody
      : '{' statements += TypeStatement* '}'
      ;

    TypeStatement
      : Attribute
      | Reference
      | Check
      | Abstract
      ;

    Abstract : 'abstract' ;

    Check
      : 'it' Expression<String>? '{' expressions += Expression* '}'
      ;
      
    Attribute
      : 'attr' name = NAME ',' type = Expression<PAbstractType> AttrBody?
      ;

    AttrBody
      : '{' statements += AttrStatement* '}'
      ;
      
    AttrStatement
      : AssignmentExpression # in program model i.e. $x = Expression
      | FunctionDefinition   # as shown above
      | Check
      ;
      
    Reference
      : 'has' name = NAME ',' type = Expression<PAbstractType> AttrBody?
      ;
      
Attributes holds values by containment - i.e. are mapped to ecore:

* has_attr
* has_many_attr
* contains_one_uni
* contains_many_uni
* contains_one
* contains_many

Depending on the declared puppet type (i.e. if the type can be represented by an
score data type, or an ecore class, the multiplicity, and if a containment reference
should be bidirectional or not. 

We could expose more control over bi-directionality but it requires cross-mapping of names.
Can probably be done by just setting appropriate attributes.

References are mapped to non-containment ecore references. The referenced instance must naturally
be contained in something that is serialized and available or it will not be possible to deserialize.

We may want to hold of implementing non containment references.

### Resource Type

Thoughts about mapping the current Resource to the proposed way of writing types in the
Puppet Programming language and using score.

### Inherits Resource

A resource type inherits the base class ResourceType which defines some base attributes
(e.g. title). (In the Puppet Type System, the `Types::PResource` type currently does not have
any such behavior defined for Resources, it does not know about the individual concrete
types e.g. `Resource[File]`, it is just a reference.

    type my_resource inherits Resource

Puppet does currently not support inheritance of a specific Resource type  i.e. this is
currently not supported:

    type my_file inherits Resource[File]

### Attributes

#### name var

This can be handled by a variable setting - e.g.

    $isnamevar = true

in the attribute body

This implies that we need to store the information about what variables can be set
like this. Having a model of annotations per type helps making this more flexible
and helps those that write tools that process models.

#### ensurable

This is written as a regular attribute named `endurable`, and having `Enum` kind. Nothing else
is required.

#### Auto Require

This is handled by the base resource type having an attribute like this:

    attr auto_require, Array[Type[Resource],0, default]
    
i.e, an optional array of type references. Validation checks that the Resource types
are fully qualified down to primary key ("namevar").

#### Property vs Parameter

This is handled by setting variables in the attribute body. If nothing is stated, the attribute
is a parameter. If we keep the same nomenclature:

    $property = true #
    
But this could also be called $discoverable (the value can be discovered on the system),
$synchronizeable (the value can be both discovered and written), and $writeable (it can be written,
but the current value is not discoverable). Maybe the three terms are readable, writeable and synchronizeable (i.e. shorthand for setting both readable and writeable).

Implementation wise, these are stored as annotations in the ecore model. The base implementation
of Resource has methods that makes it easy to ask for these values.

Example
===
This example is the custom package from the O'Reilly book "Writing types and Providers", rewritten
using the Puppet Programming Language's support for types.

    type custom_package inherits Resource {
      attr ensurable, default_ensurable  # defined elsewhere to be Enum[absent, present]

      attr name, String[1] { $namevar = true }

      ## Version of Package that should be installed
      attr version, Pattern[/^[A-Z0-9.-]+§/] { $synchronizeable = true }
      
      ## Software installation http/https source, or absolute file path
      attr source, Variant[URI[http], AbsolutePath]
      
      ## whether config files should be overridden by operations
      attr replace_config, Enum[yes, no] { $default = no }
      
      ## Example of invariant
      it "must have source set if ensure is 'present'" {
        $ensure == present and !$source
      }
    } 

The example above makes use of new invented types; URI, and AbsolutePath. If they are not
present these could be expressed as `Pattern`, or `Variant` type, or with a custom validation that calls other
functions.

    function validate {
      is_absolute_path($it) or is_http_uri($it)
    }
    
Now, there are invented functions instead...

Actions
===
* Function definition, and definitions only available inside types
  * a 'new' function that can instantiate a type (Resource and others - this is
    similar to the create_resources function).
  * explore what the set of type functions should be
    * casts / transform
    * creation / initialization
    * injection (to get handle to a service)
* Add additional types
  * Lambda
  * Path, AbsolutePath, RelativePath
  * URI[scheme]
* Parsing
  * new tokens
  * grammar
  * model
  * factory, dumper, label provider
* Loading
  * given a reference, where is it found?
* Agent
  * agent side functions
    * all functions everywhere, or declarative where they can be used?
  * agent side Puppet code evaluation
    * scope that is free of compiler concerns
    * validation for agent side logic, or just let it end with error?

* Catalog
  * Are types free of resource dependencies/notification concern?
    * Could be modeled by having Resource <-*-> Resource relationship
    
* Planned Catalog
  * This is a transformation to the future "catalog" sent to the agent
  
* Current Catalog
  * This is a transformation to the current "unplanned" catalog that the agent plans and
    acts on.
    
* Transformation of existing types to new catalog/type-model to allow them to be used
  * This raises the issue that the implementation of a type should perhaps be kept separate
    and instead be referenced via an annotation (i.e. it is a 3x implementation, or a new
    puppet based implementation). 
    
     

    
  