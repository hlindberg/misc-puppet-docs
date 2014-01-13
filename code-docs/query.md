The query operations
===
The query operations in 3x are quite bad.

* The grammar has several restrictions, and allows constructs that fail
* Has undefined behavior for more advanced forms of searches
* Can not express the full range of queries that can be performed with PuppetDB
* Uses two different mechanisms for virtual and exported queries - but constructs both
  types of queries even if only one is used
* Queries are lazily evaluated by the compiler (probably because they can define
  attribute override operations).

Options
---
* Transform queries to 3x AST, evaluate those and ignore all the issues
* Evaluate queries to PuppetDB type queries (lisp/clojure like)
  * For virtual queries, transform the PuppetDB queries into higher order predicate function
* Modify the grammar to support the full range of PuppetDB queries
* Separate the query from the realization and override behavior

Transform to 3x
---
This is the easiest, but does not offer any advantages over 3x. The behavior is bad enough to
deserve deprecation in favor of a better solution - i.e. deprecate the spaceship operators as they can not be improved upon without breaking backwards compatibility - better to fail completely
than to have surprising effect.

Evaluate queries to PuppetDB type queries
---
The PuppetDB query API is simple to handle. All backends should use this - including the
virtual query.

A major rewrite of the 3x Collector, Collection, CollExpr and how these are used by the compiler
is required. This is not recommended.

Modify the grammar
---
Supporting the full range of the Query grammar is a better approach. 

The queries can be expressed in SQL like fashion rather than magic operators - i.e.

    SelectExpression
      : 'select' ('@' '@'?)? Type '{' QueryExpression '}'
      ;
      
    Type
      : QualifiedReference
      ;
    
    QueryExpression
      : BinaryQueryExpression
      | BooleanQueryExpression
      | SubqueryExpression
      ;
      
    BinaryQueryExpression
      : Field '==' Expression
      | Field '<' Expression
      | Field '>' Expression
      | Field '<=' Expression
      | Field '>=' Expression
      | Field '~' Expression
      ;
      
    BooleanQueryExpression
      : QueryExpression 'and' QueryExpression
      | QueryExpression 'or' QueryExpression
      | 'not' QueryExpression
      ;
      
    SubqueryExpression
      : Field 'in' 'extract' Field 'from' SelectExpression
      ;

An `Expression` is evaluated, and the result is used as the value; the value must be
a basic datatype; string, integer, float, boolean, or pattern (regexp). Only ~ accepts
a regular expression as RHS value (also accepts a string representing a regular expression).

### Result Set
The result of a query is enumerable/array, and users can call the following functions for each
element.

     override(resource, hash_with_overrides)
     realize(resource, hash_with_overrides)
     
     # This could also be allowed to set overrides (it is already the syntax for
     # overrides, and the $resultset does not look like an array of names - it is an array
     # of resources
     #
     Resource[$resultset] { attribute_operations }     
     