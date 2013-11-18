

Catalog Expressions
===
Catalog Expressions are those that more directly relate to the content of the catalog produced
by the compilation of a Puppet Program.

* Node Definition - associates the logic producing a particular catalog with the node making 
  a request for a catalog.
* Class Definition - creates a grouping of resources
* Resource Type Definition - creates a new (User) Resource Type
* Resource Expression - creates resources
* Resource Default Expression - sets default values for resources
* Resource Override Expression - sets
* Relationship operators - orders the entries in the catalog

This chapter focuses on the syntactic aspects of these expressions. There are additional semantic rules, rules specific per type (extensible set), evaluation order semantics, as well as semantics for
catalog application that are covered in a separate chapter. (TODO: REF TO THIS CHAPTER).

Auto Loading
---
* Name of definitions must be stored in a file that corresponds to its name
* Nested constructs are only visible if parent is loaded (TODO: ??? - there is a search...)
* 

### Shared Syntax

These syntactical rules are common to several of the catalog expressions:

    ParameterList
      : ParameterDeclaration (',' ParameterDeclaration)* ','?
      ;
      
    ParameterDeclaration
      : VariableExpression ('=' Expression)?
      ;
    
    VariableExpression : VARIABLE ;

* The VARIABLE must contain a simple name

### Node Definition

Syntax:

     NodeDefinition
       : 'node' HostMatches ('inherits' HostMatch)? '{' Statements? '}'
       ;
       
     HostMatches
       : HostMatch (',' HostMatch)*
       ;
       
     HostMatch
       : SimpleName ('.' SimpleName)*
       | SingleQuotedStringExpression
       | DoubleQuotedStringExpression
       | LiteralDefault
       | RegularExpression
       ;
       
     LiteralDefault: 'default' ;
       

* The HostMatch consisting of a sequence of period separated simple names should contain
  no spaces.
* All host matches (except regular expression and literal default) must consist of a 
  sequence of characters `a-z A-Z 0-9 _ - .`
* The combination of regular expression host match, and inherits is undefined
* Inheriting from a NodeDefinition with multiple host matches is possible by using the
  one of its host matches after inherits in another node.
* Circular inheritance is not allowed
* The ambiguity of having multiple host matches that match a particular compilation request is
  resolved by selection of the first NodeDefinition with a matching HostMatch.

<table><tr><th>Note</th></tr>
<tr><td>
  The 4x implementation uses the 3x logic to evaluate NodeDefinitions, the only difference
  is the parsing of HostMatch - 3x allowed QualifiedName to contain '.', but these are not
  allowed elsewhere in the language.
</td></tr>
</table>

### Class Definition

Syntax:

    ClassDefinition
      : 'class' ('(' ParameterList? ')')? ('inherits' QualifiedName)? '{' Statements? '}'
      ;
      
    
* A class definition may only appear at the top level in a file, or inside a class definition
* A class may inherit another class
* A class may have parameters
* A parameter declaration may have a default value expression
* Parameter declarations with default value expression may appear anywhere in the list
* Parameter default value expressions
  * may not reference other parameters in the list - the evaluation order is undefined
  * may reference variables defined by the inherited class (it is initialized before the
    inheriting class).
* A class defines a named scope and makes all of its parameters and variables visible
* A class defined inside another class automatically becomes prefixed with the containing class'
  name as its name space

<table><tr><th>Note</th></tr>
<tr><td>
  The 4x implementation uses the 3x logic to evaluate ClassDefinition. There are many
  additional (some unclear) rules that needs to be specified (and/or fixed).
</td></tr>
</table>


### Resource Type Definition

Syntax:

     ResourceTypeDefinition
       : 'define' QualifiedName ('(' ParameterList? ')')? '{' Statements? '}'
       ;

* A ResourceType named the same as a type provided in a plugin will never be selected
* The default parameter value expressions may not reference variables in the calling scope, and
  may not reference any of the other parameters in the list. It may reference meta parameters.
* A define may occur at top level, or inside a class
* A resource type defined inside a class automatically becomes prefixed with the containing class'
  name as its name space.
* A resource type defined in a class only becomes visible if the class is loaded

<table><tr><th>Note</th></tr>
<tr><td>
  The 4x implementation uses the 3x logic to evaluate Resource Type Definition. There are many
  additional (some unclear) rules that needs to be specified (and/or fixed).
</td></tr>
</table>

### Resource Expression

### Resource Default Expression

### Resource Override Expression

### Relationships

Queries
---