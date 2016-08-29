How the agent works
---

The agent receives a catalog which is a simple serialization of:

* list of classnames that were used
* each resource with
  * attributes
  * tags
  * "meta information" exported, noop, etc.
* a list of edges between attributes
* a catalog version 

Notably, there are several pieces of information known during the compilation that are lost.

* if a resource was imported
  * from where was it exported
  * where was the imported export realized (in source)
* the source location of the expression that set an attribute value
* containment information has been transformed to edges

Other deficiencies:

* Only one desired state per resource identity is possible. A series of state changes cannot
  be described (e.g a file must first contain information X, in order for other resources to
  be synchronized, information obtain from their end state requires the file to now also contain
  information about Y in order to complete with yet more resources). This must be done with multiple 
  catalogs, or trying to do things in hooks triggered at the end.
* The type of a resource is a name only, it is expected that this name resolves to the same type
  at both the master and agent end.
* Only the set of datatypes that can be represented by the supported serialization format can be
  used; i.e string, numeric (int/float), array, object (hash), boolean, nil/null. This requires that
  each attribute is aware of special encoding in a data type representation to be able to 
  differentiate between data types. This works in practice if values are single typed and the
  data type can be represented in string form (e.g. a regexp). But it does not work if th type
  is Variant[String, Regexp] since it would require the string for a regexp to have an encoding,
  say using  / / around the regexp - now strings cannot start end with / /, and they also need to
  be encoded, we may end up with %r{regexpstring} and %s{string}. Next complexity is if we want to
  also accept a hash Variant[Hash, String, Regexp], we want to encode it as an object, but we cannot
  do this because the serialization format's hash is already used to represent a hash. Thus we must
  again have magic encoding.
* There is no schema: Types are implementation specific, there is no polyglot description of them 
  (i.e. the knowledge that 
  serialization contains say %r{}/%s{}, or hashes with "magic" keys is up to the implementation. 
  (There is a schema for the catalog, but it describes the simplistic catalog format).
  
Resource Types and Providers
---
A Resource Type is an implementation in Ruby that follows an API, and is somewhat similar to
a DSL for implementing a type.

A Resource Type is not responsible for managing the actual system state, that is the job of a Provider. A Provider is also an implementation in Ruby following an API that is DSL like.

The line between a Resource Type and a Provider is somewhat blurred. The line is also blurred between a resource's states - the desired state as expressed in the catalog, the actual system state, and
the end-state (after the desired state has been applied; which may be different than the desired state since a change can be symbolic like 'latest', it should also be noted that a diff is between an actual state, and end-state.

The line is further blurred because the agent side Puppet::Resource implementation is the
base class of the Puppet::Parser::Resource used when compiling.

When the agent applies a catalog, there is one Provider instance per resource instance
