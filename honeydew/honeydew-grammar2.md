Honeydew Grammar 2

This grammar is modeled after th NOOP++ OPN.

| Noop++ | HD
|---     |---
| CLASS  | PLAN
| EXPORT name list | element visibility PUBLIC, PRIVATE
| y -> self | y -> output |
| self -> y | input -> y  |
| Null      | Unit        |


~~~

// CLASS
Plan
  : 'plan' (NAME 'inherits' NAME)? '{' PlanBody? '}'
  ;

PlanBody
  : Field
  | Function
  | Action
  ;

Field
  : Type? NAME ('=' Value)  # Type inference
   
  
Value
  : Literal
  | NAME
  | Instantiaion
  | Type
  
Instantiation
  : NEW Type (prototype = NAME) '{' AttributeOperations '}'
  
  
AttributeOperations
  : AttributeOperation (',' AttributeOperation)* EndComma
  ;
  
AttributeOperaion
  : NAME '=>' Value
  ;

~~~

Instantiation

Puppet
~~~
type { title: attr => Value}

Problem - works quite differently. Natural way would be

x = new Doctor { speciality => 'cardio' }
x2 = new Doctor x ',' { handicap => 2 }

Type casting:

x = new Queue [1,2,3]

InputQueue[Patient] patients = new InputQueue


InputQueue[T]
OutputQueue[T]
Plan[{Tin}, {Tout}, id]  e.g. Plan[{doctors => Doctor}, { patients => Patient }]

SymbolicType
!
!!
counts  
  