The Resource Expression
===

The future parser creates:

* ResourceExpression
  * type_name => QualifiedName
    * enforced by ast transformer
    * check if validated
  * bodies => list of ResourceBody
  * transformed to art by:
    * transforming all the bodies
    * calling new on the AST::Resource class with the :instances set to the transformed
      array of bodies
    * the resulting AST::Resource is told about the resource form by getting the symbolic
      value from the pops model (o.form) unless the form is :regular.
      
* The ResourceBody
  * transforms to AST::ResourceInstance
    * :title = o.title
    * :parameters = set of transformed o.operations

* AttributeOperation
  * :value = transformation of o.value_expr
  * :add   = true if op == +>
  * :param = o.attribute_name
  * AST::ResourceParam hash
  * (Currently location of attribute operation is lost (no positioning passed)
  
Evaluation

implements evaluate(scope)

* figures out if virtual is true (virtual form, or exported)
* iterates over bodies
* evaluates all parameters (i.e. attribute operations)
* evaluates title(s)
* calls ***scope.resolve_type_and_titles(type, resource_titles)***, which returns the type, and
  a list of resource titles
* builds a Puppet::Parser::Resource for each title

Evaluation of a ResourceParam
* returns a new Puppet::Parser::Resource::Param
  * name - name of param
  * value - evaluation of instructions value
  * source - gets the source from the scope given a hash of line and file from the instruction
  

## GOTCHAS
A Puppet::Resource::Type is involved in instantiating the Puppet::Parser::Resource (if it is of
that kind).

The Puppet::Parser::Resource is added to the compiler
The compiler is told to evaluate classes (good thing, if Resource was responsible for this
it would be bad).

Puppet::Parser::Resource < Puppet::Resource

