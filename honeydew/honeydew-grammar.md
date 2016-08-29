The Honeydew Grammar

~~~
Plan
  : Visibility 'plan' NAME ('inherits' NAME)? '{' expressions += PlanExpression* '}'
  ;
  
PlanExpression
  : Queue | Input | Output | Action | Flow
  ;

//--- Queues
//  
Queue : 'queue' QueueDefinition ;
Input : 'input' QueueDefinition;
Output: 'output' QueueDefinition;

QueueDefinition
  : TypeExpression? NAME '{' QueueAttrOperations OptionalEndComma '}'
  ;

QueueAttrOperations
  :
  | operations += QueueAttrOperation (',' operations += QueueAttrOperation)*
  ;

QueueAttrOperation
  : key = NAME '=>' value = Expression
  | '*' '=>' Expression<Hash[String[1], Any]>
  ;

//--- Action
//
Action
  : Visibility 'action' NAME '(' ActionParameters ')'
                       ('=>' '(' OutputParameters ')')? 
    '{' Expressions '}'
  ;

ActionParameters
  : ActionParameter (',' ActionParameter)* OptionalEndComma
  ;

ActionParameter
  : TypeExpression DollarVar ('=' Expression)?
  ;

OutputParameter
  : ActionParameter
  ;
  
//--- Flow
//
Flow
  : Visibilty 'flow' NAME '{' FlowExpression '}'
  ;

// Semantic restrictions apply
// A pure inhibitor can only have one flow step
//
FlowExpression
  : InhibitorExpression SelectExpression? FlowStep+
  | SelectExpression FlowStep+
  ;

// doctors                 - implied select, implied variable name
// dr doctors              - implied select, given variable name
// select doctors          - specified select single entry
// select dr doctors       
// select [ doctors, ... ]  - multiple entries
// 
SelectExpression 
  : ('select'? OptionallyAliasedName  | 'select' '[' NameList ']')
      WhereClause?
      OrderByClause?
  ;


// TODO: Decide on 'unless' or '!' (or both?)
//
InhibitorExpression 
  : (('unless' | '!') OptionallyAliasedName  | ('unless' | '!') '[' NameList ']')
      WhereClause?
  ;

NameList
  : OptionallyAliasedName (',' OptionallyAliasedName)* OptionalEndComma
  
// doctors
// dr doctors
// dr[3] doctors
// dr[1,3] doctors
// dr[all] doctors
//
OptionallyAliasedName
  : alias=(NAME '[' min = INTEGER ',' max = (INTEGER | 'all') input=NAME
  ;
    
WhereClause
  : '[' PredicateExpression ']'
  ;

RelOp : '==' | '>=' | '<=' | '=~' | '!~ ;
  
PredicateExpression
  : PredicateExpression 'and' PredicateExpression
  | PredicateExpression 'or' PredicateExpression
  | '!' PredicateExpression
  | '(' PredicateExpression ')'
  | PrimaryExpression RelOp PrimaryExpression
  ;

PrimaryExpression
  | ValueReference
  | Literal
  ;

// TODO: These are not described in more detail - should be obvious what they
// are (this is shared with puppet in general with additional semantic restrictions
// and that bare words are variables/references, not strings.
//  
Literal
  | LiteralArray
  | LiteralHash
  | LiteralString
  | LiteralNumber
  | Regexp
  | LiteralTypeExpression
  ;
  
OrderByClause
  : 'order_by' (ColumnSpec | ('[' ValueExpression (',' ValueExpression)* OptionalEndComma ']')
  ;
  
ArithmeticOp : '+' | '-' | '*' | '/' | '%'
ValueExpression
  : ValueExpression ArithmeticOp ValueExpression
  | ValueExpression RelOp ValueExpression
  ;
  
  
// Navigating to value
// e.g. dr => available_doctors.name, first_wheels_hubcap => car.wheels.0.hubcap
//
ValueReference
  : NAME ('.' (NAME | NUMBER))*
  ;

FlowStep
  : '->' NAME OutputMap?
  | '->' OutputMap
  ;

OutputMap
  : '{' ValueReference '->' NAME (',' ValueReference '->' NAME)* OptionalEndComma) '}'
  ;
  
OutputMapEntry
  : ValueReference '->' NAME
  | NAME
  
  
//--- General
//
Visibility
  : 
  | 'private'
  ;
  
//-- Common with PuppetGrammar  
//
OptionalEndComma : ','?

NAME : <NAME TOKEN> ; # Puppet TOKEN lower cased (optionally qualified) name

TypeExpression
  : Type
  | Type '[' Expression+ ']'

Type : <CLASSREF TOKEN> ; # Puppet TOKEN upper cased (optionally qualified) reference

Expression : ... ; # Puppet Expression (too much to include in this grammar)
  
~~~



SQL-like
---
    
Two longest waiting doctors go to play golf

    flow {
      select   [ dr1 available_doctors, dr2 available_doctors ]
      where    [ dr1 != dr2 ]
      order_by [ { $dr1.waiting_time + $dr2_waiting_time } desc ]
      -> golf

     flow {
       unless waiting_patients
       select [ dr1 available_doctors, dr2 available_doctors]
       where  [ dr1 != dr2 ]
       order_by [{ $dr1.waiting_time + $dr2.waiting_time } desc]
       -> golf
       -> ... 
       
One to 3 doctors handles an emergency

     output Patient observation
     flow "1, up to 3 doctors handle an emergency" {
       select [ doctors[1,3] available_doctors, pat waiting_patients ]
       where  [ pat.emergency ]
       }
       -> er_procedure {
           *doctors -> available_doctors,
           pat -> observation
         }
     }
     
An emergency inhibits normal picking:

    flow "emergency has priority" {
      unless waiting_patient where [ waiting_patient.emergency ]
      -> consultation
    }
    
Patient Doctor

    plan physicians_practice {
      type Document = ...
      type DrPatient = Struct[{pat => Patient, dr => Doctor, free_room => Integer}]
      input Doctor available_doctors
      input Patent waiting_patients
      output Document archive
      queue DrPatient consultation
      
      flow "doctor consults with patient and produces document" {   
        select   [ dr available_doctors, pat waiting_patients ]
        order_by [ {dr.speciality == pat.speciality} desc, pat.wait_time desc, dr.wait_time desc ]
        -> consultation
        -> examination {
             dr -> available_doctors,
             pat -> drain,
             document -> archive
           }
       }
       
       queue Integer free_room {
         add_all => Integer[1,10]
       }
       flow "examination takes place in a room" {
         select free_room
         -> examination
         -> [free_room, {room => free_room}]
       }
    }
