Honeydew
===
Honeydew is an experimental implementation of an Object Petri Net (OPN) with support
for colored, structured, timed  Petri-Nets. The implementation is specific to Puppet.

Honeydew is named after the Muppet "Baron Petri Honeydew" [1], an uncle of Dr Bunsen Honeydew.

[1]:http://muppet.wikia.com/wiki/Baron_Petri_von_Honeydew

THIS TEXT IS W.I.P

Petri Net
---
A Petri Net is a more advanced form of a Finite State Machine. It consists of
Places (contains tokens), Transitions (that consumes tokens
in input Places, performs some work and produces tokens in output Places).

Places and Transitions are connected via Arcs.

P -> T

An arc from P to T, consumes one or more tokens from P.

Tokens have Type, and as tokens flow through the network they are said to color the
Places and Transitions. (In most cases "color" is synonym to "type").

Here is a simple textual representation of an Elevator traveling between two floors:

    place floor1, floor2
    transition up, down
    
    up(floor1)   => floor2
    down(floor2) => floor1
    
There are several extensions to the basic form of Petri Nets (PN) - the two extensions included
in Honeydew are; Colored Petri Nets and Object Petri Nets. A Colored Petri Net (CPN) adds
Type to the tokens; in the original PN tokens are all of the same type (Unit) and do not
carry any more information. CPN also adds the concept of Time as well as hierarchical networks.
An OPN adds the Type OPN as a token type - it is thus possible for one network to instantiate and
interact with multiple instances of a petri net.

### Honeydew Concepts

Honeydew is based on OPN (which includes CPN) but uses a slightly different terminology. The main
purpose of PN technology is to design, simulate and analyze distributed asynchronous processes and the main purpose of Honeydew is to execute such a process. All Honeydew concepts are transformable
to a corresponding (O)PN. (This makes it possible to to design and validate designs. Automatic translation may be possible, and it may be possible to transform a Honeydew design to PN form for analysis - this is however a separate topic). The reason this is somewhat fuzzy a.t.m. is that a true
Petri net requires a quite rigorous specification and Honeydew introduces several shortcuts and
extensions (that at this point has not been fully thought through).

Since the target audience of Honeydew are Puppet programmers and those that consume Puppet
manifests, the terminology from Petri net theory has been changed as follows:

| Petri       | Honeydew             |
| ---         | --------             |
| Network     | Plan                 |
| Place       | Input, Output, Queue |
| transition  | Action               |
| -           | Process              |

The term `Plan` was later changed to `Actor` - this document has not been updated with that change
in terminology. Also changed in later examples is a more puppet like syntax where all variables use a $prefix.

The two main concepts are `Plan` and `Process`. A `Plan` corresponds to an executable computer 
program, and a `Process` corresponds to an instance of an executing `Plan`.

A `Plan` is reminiscent of a command line utility/program into which it is possible to pipe input (stdin) and get output on one (stdout), or multiple streams (stdout, stderr). Just like a program that opens multiple additional stream, a `Plan` can have additional inputs and outputs.

The Petri net concept of `Place` is called `Queue` in Honeydew. The queues on the edge of a plan (that connect to the outside world) are called inputs and outputs; in every other respect they are
queues. Honeydew also has a number of pre-configured queues (for convenience) called `start`, `end`, `fail`, and `drain`.

An `Action` is reminiscent of a function - it has inputs and outputs represented by
typed queues and a body of logic. Conceptually it can be viewed as a call to the function that
takes place when all of its inputs are available, and the outputs can accept more output.

A `Process` executes `Actions` when they are *ready to run*. It accepts inputs asynchronously, and produces outputs asynchronously. Actions are triggered in thread safe fashion and may run in parallel on different threads. An action can not asynchronously receive inputs our produce outputs while it is running - all its inputs are given when it is triggered, and all outputs are produced/enqueued when the action is completed.

An action's dequeuing and enqueuing is referred to as **pick** and **put**.
Picking is by default done by getting the oldest (longest waiting) item in a queue. By default everything that was picked is also put to the output.

    
### Example - Physicians Practice

A Physician's Practice has a waiting room where patients enter. A doctor consults with
a patient when the doctor is free. A doctor documents a consultation when it is over,
the patient is then done, and the doctor is free to consult with the next patient.

    plan physicians_practice {
      input Patient waiting
      input Doctor free
      output Document archive

      queue Struct[{p => Patient, dr => Doctor}] consultation
      queue Patient done {
        ttl => 0 # patient leaves
      }
      
      # A match of patient and doctor is performed - if patient needs a specialist
      # and doctor is one, then this patient-doctor goes into consultation, else
      # the doctor picks the patient having waited the longest.
      # (Without the 'select best' the longest waiting doctor would consult with
      # the longest waiting patient).
      #     
      action next {
        pick waiting => $patient
        pick free    => $doctor
        select best { if $patient[specialist] == $doctor[speciality] {2} else {1} }
        put $doctor, $patient => consultation
      }

      # Doctor examines patient, doctor writes a document
      # Then patient is released, doctor files the document, and is again free to pick
      # another patient.
      #
      action examination {
        pick consultation[doctor]  => $doctor
        pick consultation[patient] => $patient

                
        # take blood pressure
        # listen to heart
        # etc
        $document = { pressure => ..., heart => ... }
        
        put $doctor   => free
        put $patient  => done
        put $document => archive
      }
    }
    
When type alone cannot identify each data element, they must be tagged with a "color". If
both doctors and patients were identified by strings we would have to "color them" manually -
here by constructing a hash since the system cannot figure out which string is which when
they are put into the consultation place.

    plan physicians_practice {
      input String waiting
      input String free
      # ...

      queue Struct[{p => Patient, dr => Doctor}] consultation
      # ...
      action next {
        pick waiting => $patient
        pick free    => $doctor
        select best { if $patient[specialist] == $doctor[speciality] {2} else {1} }
        put {dr => $doctor, p => $patient} => consultation
      }
    # ...
    }

### Plan

A `Plan` describes a process in terms of inputs, outputs, queues and actions. Inputs and outputs are optional - if it has no inputs, data cannot be sent to the process. If it has no outputs no data is sent from the process (except the process' exit status - if it ever exits that is).

* The input and output definitions of a plan are also queues.

* A plan may declare data types.

* All plans have predefined queues (start, end, drain, fail) - as described below. These are default
  queues and may be redeclared with different behavior.

### Queue

A `Queue` is a named storage location where instances of data are waiting to be processed. All
actions take data from one or more queues and deposit result(s) in one or more queues.

A `Queue` is typed. The input queues of a Plan must be explicitly typed.
The type of intermediate queues and
output queues may be left out as they can be inferred. (Inference may hide errors and it is
always best to explicitly type output places when a plan is included as a sub plan of a larger plan).

By default a Queue receives data which is enqueued for consumption. When the data is consumed it is removed from the internal queue. A Queue may however have different behavior controlled by parameters. It may be initialized with a value when the plan is created, it may also hold on to the last value seen, it may discard values after a time-to-live period has expired etc.

Internally, a Queue holds on to both enqueued and future-values (promises), values that (most likely) will be enqueued when an action
completes. Holding future values is done to ensure proper flood-control; an action is triggered when all its inputs
are available, and the outputs can receive additional output when an action is running. At the start of the action, capacity is reserved in the output queues. When the action completes, the promises are either fulfilled or the promise is retracted. A queue always includes the reserved capacity when it calculates its available capacity.

#### Queue Parameters

A Queue has the following parameters.

* **latch** - when data arrives it is latched and can be consumed any number of times, optionally until
  a time to live (TTL) for that object has been reached. Latched mode implies that capacity is 1, and that a new value replaces the current value and that TTL is then reset. (This is a short hand for what would otherwise require two places and a latching action that outputs a copy to the input and to another queue; `latch(q1) => [q1, q2]`).

* **add** - a reference to an expression that is evaluated and the value automatically added to the queue when the plan is initialized.

* **add_all** - a reference to an expression that is evaluated and if the value is a collection, each
  value is automatically added to the queue when the plan is initialized.

* **capacity** - the maximum number of entries in the queue at any given time. By default the capacity
  is unlimited. The capacity includes promised/future values that may be retracted.

* **ttl** - the maximum time an entry will live if not consumed. By default unlimited.

* **schedule** - a "crontab entry" that creates a Time data element in the queue
  (if it has capacity or is 
  latched). The
  value is a crontab entry string extended with an extra slot for second. This is a shorthand
  for `cron(q1, !q2) => [q1, q2]` - a token is produced in q2 at the specified time, unless there is 
  already a token in that place (i.e. the token for the last time the timer ticked has not yet been
  consumed).

* **exit** - an exit queue that if it receives a token will stop the process running the plan (freeing 
  up all data). The exit event is sent to the creator of the process (or to a entity the creator has 
  delegated the responsibility to). An attempt is made to flush output places - if this times out, the 
  output is lost. The specified exit value is sent to the creator. (*TODO*, possibly also send the token 
  that is given to the place; e.g. error message, faulty object etc. This is probably needed to wire a subplan into a larger plan i.e. an exit queue is also an output).


#### Default Queues

There are default, preconfigured queues that a user would otherwise typically create in
almost every plan. They exist, but does not have to be used. They can also be redeclared with
different values if so desired.

* **drain** - A "drain" place is always available in every plan. It deletes data as it arrives (compare 
  to /dev/null). This is a shorthand for a queue of type `Any` with ttl = 0.

* **start** - A "start" queue is a initialized with a `Boolean` true item. This is useful when the
  plan has no other input and a single activation is wanted of the first action.

* **end** - terminates the plan with success (exit status 0) if it receives a token

* **fail** - terminates the plan with failure (exit status -1) if it receives a token


### Action

An **Action** is a function that takes n-tokens (by default one) from each input queue tied to the action via an *arc*, performs
some function and produces n-tokens (by default one, and by default a copy of the input token) in each output queue tied to the action via an *arc*.

The input type of the action function is a `Struct` combining the types of each input.
If more than one token is taken from a place the type for that contribution is `Array[<queue-type>]`.

The action may transform the input, and may produce an output structure of different type.

An action triggers/fires/executes when all of its inputs are enabled.

An input is *enabled* if the requested n-tokens are available, and these token meet the input criteria of an additional optional guard type and boolean guard expression. The oldest available tokens meeting the criteria are selected.


> TODO: Several typos/errors in the example below



    action name($param = pick(place[key], 2), $place2, ...),
               select best { if $param[x] == $place[y] {2} else {1} }
               => [
               
    action next($param = pick(place[key], 2), $place2, ...) {
      select best { if $param[x] == $place[y] {2} else {1} }
      action {
      }
    }
      
    action name {
      pick $param from place[key], 2
      pick $place2
      select best {
        if $param[x] == $place[y] {2} else {1} }
      }
      put 
      # action
    }

    plan physicians_practice {
      input Patient waiting
      input Doctor free
      output Document archive

      queue Struct[{p=>Patient, dr=>Doctor}] consultation
      queue Patient done
      

      # A match of patient and doctor is performed - if patient needs a specialist
      # and doctor is one, then this patient-doctor goes into consultation, else
      # the doctor picks the patient having waited the longest.
      #      
      action next {
        pick waiting => $patient
        pick free    => $doctor
        select best { if $patient[specialist] == $doctor[speciality] {2} else {1} }
        put $doctor, $patient => consultation
      }

      # Doctor examines patient, doctor writes a document
      # Then patient is released, doctor files the document, and is again free to pick
      # another patient.
      #
      action examination {
        pick consultation[doctor]  => $doctor
        pick consultation[patient] => $patient

                
        # take blood pressure
        # listen to heart
        # etc
        $document = { pressure => ..., heart => ... }
        
        put $doctor   => free
        put $patient  => done
        put $document => archive
      }
    }

### Arcs

As noted in the description of Action, an *arc* ties a queue to an action; there are three kinds; input, output, and inhibiting. An input arc defines which actions that consume from the queue, and analogous an output arc defines which actions that produce tokens to a queue. An inhibitor arc prevents an action from firing when the associated queue holds a token/value.

Action Rules
---
An action is enabled (is ready to run) when (and only when):

* All input arcs are enabled
* All output arcs are enabled
* An input arc is enabled when it satisfies the constraints (type), count and filter
* An output arc is enabled when the queue it targets has spare capacity
* An inhibiting arc is disabled if there is no filter and there are values, or if it has a filter and it accepts one of the values in the queue
* No disabling/inhibiting arc is enabled
 

Honeydew Language
---
This is tentative syntax, no attempts have been made yet to implement this as part of the
Puppet Programming Language. 

    Plan
      : 'plan' NAME '{' expressions += PlanExpression* '}'
      ;
  
    PlanExpression
      : QueueDeclaration
      | InputDeclaration
      | OutputDeclaration
      | ActionDeclaration
      | SubplanDeclaration
      | Arc
      ;
  
    QueueDeclaration
      : 'queue' NAME ('[' Type ']')? ('=' max_capacity = INTEGER)?
      ;
      
    InputDeclaration
      : 'input' NAME '[' Type ']' ('=' max_capacity = INTEGER)?
      ;
      
    OutputDeclaration
      : 'output' NAME '[' Type ']' ('=' max_capacity = INTEGER)?
      ;
        
    ActionDeclaration
      : 'action' NAME
      # TODO: Action, parameters, etc
      ;

    SubplanDeclaration
      : 'subplan'
      # TODO 
      ;

    Arc
      : action = NAME '(' ActionInputs ')' SelectClause? '=>' ActionOutputs
      ;
    
    ActionInputs
      : inputs += ActionInput (',' inputs += ActionInput)*   
      ;
      
    ActionInput
      : ((inhibit ?= '!') | (color = NAME))? 
        queue = NAME ('[' type_filter = Type ']')? ('=' pick = Range)?
      ;
      
    ActionOutputs
      : outputs += ActionOutput
      | '[' outputs += ActionOutput (',' outputs += ActionOutput)* ']'
      ;
    
    ActionOutput
      : (color = NAME)? queue = NAME ('[' type_filter = Type ']')? ('=' count = INTEGER)?
      # TODO: Where, if color is given or combined type (use action name?)
      #
         
    SelectClause
      : 'select' 'oldest'
      | 'select' Selector
      | 'select' 'best' Selector
      ;
      
    Selector
      : NAME '(' args += Expression (',' args+= Expression)* ')'
      | '{' expressions = Expression* '}'
      ;
      
### Expression

An Expression is a Puppet Programming Language Expression (sans catalog expressions).      
      
### The select clause

When a transition checks if it can be fired, it picks tokens from its input queues
constrained by the input specification (the number and types of tokens to pick). When these
constraints can be satisfied, the optional select clause is given each result from a
cartesian product of the inputs sorted so that the oldest combination appears first (i.e. the combined age of the inputs). The select clause may refer to the inputs by the given colors
(colors must be given in order to reference the inputs).

The select expression `select_oldest` is the default and does not have to be specified, it
simply selects the oldest combination that meets the constraints. It may be spelled out for
clarity.

A `select_best` expects the following `Selector` expression to produce a ranking per given
row. The returned value must be `Numeric`, and the row with the highest value is selected.
All rows are fed to the selector expression before one is picked.

A `select` without the keyword `best` expects the selector to produce a `Boolean` (or it is an
error), the row that first causes the selector expression to produce `true` is picked (and the
remaining rows are ignored). The rows are always presented with the oldest combination first.
If a `true` value was not produced, then the the RHS action is not triggered.

The selector is either an expression block, or a function call to a named function.
The arguments are the names of the colors/aliases given to the inputs, possibly with a reference to a detail in the given argument - i.e. `doctor[speciality]` (if a Doctor has a speciality attribute).

If the selector is specified with a block expression, the colors are bound to variable names
(e.g. $doctor, $patient).


As an example, if a Doctor has a speciality (e.g. 'cardiology') and there is a patient waiting
that needs a doctor of this speciality, this combination of doctor/patient is given a higher score.

    [{doctor => free}, {patient => waiting}]
     -> select_best |Doctor $doctor, Patient $patient| {
      if $doctor[speciality] == $patient[specialist]
        { 2 }
      else
        { 1 }
    } -> consultation

    
## The 7 archetypes

There are seven archetypical constructs

* sequence
* conflict (or)
* confusion
* concurrency
* synchronization
* merge
* priority / inhibit

### Sequence

    plan sequence {
      start -> action1 -> action2 -> action3 -> end
      
      action1 { }
      action2 { }
      action3 { }
    }

### Conflict (or)

    plan conflict {
      queue a
      queue b
      queue c
      
      start -> action1 -> a
      start -> action2 -> b
      start -> action3 -> c
      
      action1 { }
      action2 { }
      action3 { }
    }

Here, multiple actions are enabled at the same time. 

> In CPN one of the transitions/actions is selected non-deterministically.

In Honeydew, the firing will take place in round-robin fashion where the selected action will be the one with the longest waiting time since its last firing.
(Thus, at any given time there are more than one enabled action, the one waiting the longest
to fire is selected). In a tie, the transition with the lexicographically earlier name is
selected.

In the example, `action1` will win, since there is a tie (all have waited the same amount of time (0), and action1 is lexicographically first.

### Concurrency

    plan concurrency {
      queue a
      queue b
      
      start -> action1 -> [a, b]
      a -> action2 -> drain
      b -> action3 -> drain
            
      action1 { }
      action2 { }
      action3 { }
    }

    
Here, each time `action1` fires, a copy of its input (value from start) is placed in `a`, and `b`, which causes the remaining actions to fire (in this example the produced output is irrelevant).

### Synchronization

    plan synchronization {
      queue a
      queue b
      queue c
      
      [a,b] -> action1 -> c
      
      action1 { }
    }
    
Here, `action1` fires when there is a token in each of the queues `a`,and `b`, and it produces
the synchronized result in `c`.

### Confusion

    plan confusion {
      queue a
      queue b
      
      a     -> action1 -> ...
      [a,b] -> action2 -> ...
      b     -> action3 -> ...
            
      action1 { }
      action2 { }
      action3 { }
    }
    
Since there is no guarantee that tokens appear in `a` and `b` at the same time it is non deterministic which one of the actions will fire. (Only one of them can fire; `action2` if there is a token in both `a` and `b`, and one of the other actions if only `a` or `b` has a token).

This is non deterministic in Honeydew in general too. However the round robin scheduling of each queue's outputs is used to select a winning action. This makes the case when there is a steady supply of tokens in both `a` and `b` deterministic. In the first round `action1` wins over `action2` for a token from `a`, `action2` cannot fire, and `action3` thus wins over `action2` for a token from `b`. The next round, `action2` wins over `action1` for a token from `a` because it has waited longer, and it also wins over `action3` for a token from `b` for the same reason. The cycle then repeats.

In practice a construct like this requires time, since determinism is only achieved if tokens for a and b are in infinite supply or are always produced in tandem in the same round. A construct involving time would hold off for a given period of time before selecting one of the three actions, thus making it possible to configure how long the plan waits for both an `a` and a `b` before processing a single a or b.

### Merge

    plan merge {
      queue a
      queue b
      queue c
      
      a -> action1 -> c
      b -> action2 -> c
            
      action1 { }
      action2 { }
    }

    
Here, the token streams are not synchronized, their paths are simply merged (they were earlier
executed in parallel, but are now merged into a sequence). If all three transitions fire,
there are two tokens in c.
    
### Priority / Inhibit

    plan inhibit {
      queue a
      queue b
      
      a       -> action1 -> ...
      [a, !b] -> action2 -> ...
            
      action1 { }
      action2 { }
    }
    
Here `action1` is enabled if there is a token in `a`, action2 is enabled if there is
a token in `a` and no token in `b`. (Which transition to fire depends on if there is 
a guard / select, or by round robin selection).

An inhibitor does not pass on any value / color. An inhibitor may have
constraints and it inhibits if the resulting constraints applied to any existing tokens
results in an empty set).

    [a, !b =~ Enum[warning]] -> action2
    
Here, action2 is inhibited if there is a string with value 'warning' in queue `b`. No value is
every consumed from b.

No token is ever consumed by an inhibitor arc.

The LHS `!b` if followed by a binary expression is a shorthand for `b.any |$x| { $x <binop> expr }`.
If it instead followed by '.', the enumeration is manual, and the above can be written:

    [a, !b.any |$x| { $x =~ Enum[warning] }]
    
Enablement can not be filtered this way - it must use a selector. Inhibitors are not included in the selector.

    [a, !b].select |$a| 

Types
---
Additional types

`Plan`, parameterized by its inputs and outputs (name and type) - alternatively also a
reference to a named plan - e.g. `Plan[b]`

    Plan[{input => {a => Integer, b=>String}, output=>{result => String}]
  
### Drain

There is one predefined queue called drain in every plan. (This is the plan's /dev/null).
It simply forgets the tokens that end up there. This is useful as it is an error to have a action without any outputs.

(While an action without outputs could be taken as an implicit output to drain, it
is expected that it is far more common to make an error by not connecting an action's output.
With a drain, this is explicit, and the user can get errors for unconnected outputs).

TODO
---

### Arc to place with guard?

Should there be a guard on the action's output arcs? It should be possible to pick a color,
it should also be possible to pick none - i.e. no token is produced.

This becomes somewhat messy - consider guards on outputs to a, b and c.

    dox(input) => [ a select ..., b select , c select]
    
Maybe no so bad...

    # type filter on single value input
    dox(input[String]) => [ _[Enum[S, XS, XXS]] a , _[Enum[M, L, XL, XXL]] b  ]
    
The _ means "the type of the combined token in the transition", it can be omitted.


    # it is clearer with arrows !
    dox(x,y) => [ x => a, y => b ]
    
    dox(input) => [ a, b, c] === dox(input) [ _ => a, _ => b, _=> c]
    
    # type filter is applied on reference side
    dox(input) => [ Enum[S, XS] => a ] === dox(input) => [ _[Enum[S, XS]] => a ]
    dox(x,y) => [ x[Enum[S, XS]] => a , y => b]
    
    dox(x, y) => [ select foo(x) => a, bar(y) => b ]
    dox(x, y) => [ 
      select { $x < 3 } => a, 
      select { $_ =~ Struct[{x => Integer[1,1], y => Integer[1,1] } ]
      
i.e. 
* The select can call a named function where `$_`, and `$n` where n is an input name(s)
* The select can evaluate a block expression where $_ and $n... are bound to the output token
  values.

### Yield and others?

* A queue that yields - thus allowing plans to be piped?
* A queue that fails?
* A queue that means "done", not caring if there are tokens in other places

Maybe yield is implicit if a "call" is wired so that a token in a place is a yield (i.e. it is
an application issue rather than a plan issue).

### "Future" tokens

To keep track of tokens in transitions they are internally moved to the target place but with
a timestamp that indicates that they are in-transition and cannot be picked. There is a problem
if the type/guards of output arcs means that the token is only a Future in some places. There is also
a problem if the transition takes time and the conditions of the output places are changed
during this time.

    place a, b, c=1
    transition t1, t2
    
    t1(a) => c
    t2(b) => c
    
How do we know that the space in c (which can only hold one token) is not already promised
to the other transition? Answer: a FutureToken is placed in all potential places. Once the
transition has finished, the FutureTokens are resolved / swapped into either the real token, or
to nothing. 

* A FutureToken counts against capacity, but no other predication should be made based on its
  presence.
  
  
Catalogs and Plans
---
A reference to a Future requires a Plan.
At runtime, the plan must be executing
A catalog may have zero to many plans
A catalog without a plan gets a default plan (with no futures).


A catalog's default plan:

    plan main {
      sequence start -> apply_catalog -> end
   
      action apply_catalog {
        # what it does now
      }
    }
    
A catalog that contains both a client and a server part - but these are not on the same
box and included in the same catalog. Orchestration is now local. 

(TODO: Example unfinished)

    plan main {
      place start, end
      transition do_server, do_client
      
      do_server(start)
    }
    
    # Plan included for the server part
    plan db_master {
      place start, running_db
      
    }
    
    # Plan included for the client part
    plan db_client {
    }

Background Reading
===
* Modeling Business Processes - http://mitpress-ebooks.mit.edu/product/modeling-business-processes (for non technical, and semi math savvy (although those parts can safely be skipped).
* ebay blog post, with animations - http://www.technology-ebay.de/the-teams/ebay/blog/a-concurrent-monday.html
* Modeling with CPN - a gas station http://www.win.tue.nl/~cstahl/Papers/AalstSW2012_topnoc.pdf
* Object Petri Net - where the color/token can be a petri-net as well http://www.informatik.uni-hamburg.de/bib/medoc/M-329.pdf
* 

Tools
===
* PIPE (Java editor, analytics?) https://github.com/sarahtattersall/PIPE, and http://sourceforge.net/projects/pipe2/ (releases)

Alternative Syntax
===
The long form used above is easy to read from a human perspective, and it is useful
to illustrate the capabilities and change things around as everything is distinct and does not have tricky parsing issues - but it has problems:

* the wiring is hidden inside blocks
* very chatty
* harder to inherit and specialize without using things like "reopen action"


Something like this is more visually appealing:

    [waiting, free] -> next -> consultation
    consultation -> examination -> [free, done, archive]
    
Using good naming helps:

    [waiting_patients, free_doctor] -> next -> consultation
    consultation -> examination -> [free_doctor, done_patient, archived_document]
    
Actions are then simply typed:

      action next(Patient $patient, Doctor $doctor) {
      }

And the calls are based on position; values from queues are assigned to parameters left to
right, skipping any inhibiting queues. (Or enforce that inhibitors are listed first)

     [!inhibitor, queueA, queueB] -> actionX

This works when the input struct feed into the action has distinct types. When the same type appears
multiple times, a mapping must be made, and this is best done in the "calling end" - e.g.

      {patient => waiting, doctor => free} -> next -> consultation

      action next(String $patient, String $doctor) {
      }

Basically a "call by name" that is simplified to "call by type".

This also moves the select operation to outside of the action.

     [waiting, free] -> select best(Patient $patient, Doctor $doctor) {
       if $patient[specialist] == $doctor[speciality] {2} else {1}
     } -> next -> consultation
     
Now the action next is extremely simple:

     action next(Patient $patient, Doctor $doctor) { }
     
and is not needed. The user can simply wire the input to the output directly - Honeydew implies
the action - copying the inputs to the output. (We only needed the 'next' action to specify the
selection criteria).

     [waiting, free]
     -> select best(Patient $patient, Doctor $doctor) {
       if $patient[specialist] == $doctor[speciality] {2} else {1}
     }
     -> consultation

     [{p => waiting}, {dr => free}]
     -> select best (Patient $p, Doctor $dr) {
     }
     -> consultation
     
     
The rules are:

     [waiting, free] == [{waiting => waiting}, {free => free}]
     [waiting, free, !inhibitor] = [{waiting => waiting}, {free => free}, !inhibitor]

It is not an error to select on fewer queues than available.

User can change the name mapping:

     [{p => waiting}, {dr => free}] -> select_best(Doctor $dr, Patient $p) { ... }
     
The call is always by name. Types must match. The result of [queue1, queueN] or the hash
equivalence is always a struct mapping the queue name or the user given name to the dequeued value.
(Inhibitors are not included in the struct).
     
And `consultation` receives the parameters and since they types are distinct the struct can be constructed. If they are not distinct, a mapping is required

When an action creates data or take over the routing (the next action does not need this, it simply
picks 

Picking a queue that should not be carried forward in the output struct. A token is required to proceed
but it has no meaning in subsequent steps.

i.e. we start with this:

    [a, b, x] -> action

and we do not want the insignificant `x` in the struct, then we do this:

    [a, b, x] -> action_without_x(a,b)
    
The values are the optionally mapped names - e.g.

     [{p => waiting}, {dr => free}, x] -> next(p, dr)

We can do the same when the receiver is a queue (implied action without body):

     [{p => waiting}, {dr => free}, x] -> consultation(p, dr)

Picking multiple values (a given number or all available) is now more difficult to handle - but could
be written as a slice operation on the queue - say we need two doctors for every patient:

    [{p => waiting}, {dr => free[2,2]}] -> consultation
    
We can then pick at least 2 free[2] (picks all free), between 2 and 3 free[2,3], exactly 2 [2,2]. Picking 0 is allowed - it means a value must exist but that the value is not consumed (or rather that it is consumed and put back when the action completes - which would otherwise require additional wiring).

For an exact pick of more than one value the picked type is always Array[PickedType, actual_count, actual_count].


Example rewritten:

    # A Physicians Office
    # Patients and Doctors arrive from external sources
    # Patients leave when examined, doctors stay for ever
    # Process runs forever
    #
    plan physicians_practice {
      input Patient waiting
      input Doctor free
      output Document archive

      queue Struct[{p => Patient, dr => Doctor}] consultation
      
      # A match of patient and doctor is performed - if patient needs a specialist
      # and doctor is one, then this patient-doctor goes into consultation, else
      # the doctor picks the patient having waited the longest.
      # (Without the 'select best' the longest waiting doctor would consult with
      # the longest waiting patient).
      #     
      [{p => waiting}, {dr => free}] -> select_best |Patient $p, Doctor $dr| {
          if $p[specialist] == $dr[speciality] {2} else {1}
        }
        -> consultation
        -> examination
        -> {
          dr       => free, 
          p        => drain,
          document => archive
        }

      # Doctor examines patient, doctor writes a document
      # Then patient is released, doctor files the document, and is again free to pick
      # another patient.
      #
      action examination(Doctor $dr, Patient $p) => [$dr, $p, Document $document] {
        # take blood pressure
        $pressure = {upper => 117, lower => 76}
        
        # listen to heart
        $heart_rate = 70
        
        # assigns the output variable - it is an error to not do this
        $document = { pressure => $pressure, heart => $heart_rate }
      }
    }

What if after the doctor and patient they need to find an examination room? This means that
the available rooms need a token each (created when the Physician's Office is started)

We can add the rooms like this:

      queue Integer free_rooms {
        add_all => Integer[1, 10]
      }

Since we do not need anything besides a token, but it is nice to have a value to indicate
which room it is.

Then, the room must be freed when the consultation is over. The room has no bearing on
the examination itself. We can simply add this as a separate sequence:

      free_room -> examination -> {free_room => free_room }

 We are allowed to have additional values in the input to an action
(that are ignored), but that is required in the output).


*BEST EXAMPLE / SYNTAX*

    # A Physicians Office
    # Patients and Doctors arrive from external sources
    # Patients leave when examined, doctors stay for ever
    # Process runs forever
    #
    plan physicians_practice {
      type Doctor  = Struct[{speciality => String, name => String}]
      type Patient = Struct[{specialist => String, name => String}]
      type Document = Struct[{
        patient_name   => String,
        heart_rate     => Integer, 
        blood_pressure => Struct[{low => Integer, high => Integer}]]
      
      input Patient waiting
      input Doctor free
      output Document archive

      queue Struct[{p => Patient, dr => Doctor}] consultation
      
      queue Integer free_rooms {
        # there are 10 rooms named 1 to 10
        add_all => Integer[1, 10]
      }
      
      # Performs a match of patient and doctor where if patient needs a specialist
      # and doctor has speciality, then this patient-doctor combination
      # is given higher priority.
      #
      function doctor_patient_match(Doctor $dr, Patient $p) {
          if $p[specialist] == $dr[speciality] {2} else {1}
      }
        
      # Select doctor-patient combination using a best match selection. The selected
      # doctor-patient  goes into consultation. The best match that have been waiting the
      # longest is picked.
      # (Without the 'select best' the longest waiting doctor would consult with
      # the longest waiting patient without respect to any needs for a specialist).
      # 
      sequence [{p => waiting}, {dr =>  free}]
       -> select_best(dr, p) doctor_patient_match
       -> consultation
       -> examination {
          dr       => free, 
          p        => drain,
          document => archive,
        }
        
      # Specifies that a free_room is required to enable the examination action
      # (The action is not aware of this)
      # The room is returned to the queue once the examination is done (again
      # the action is not aware of this requirement).
      #  
      sequence free_room -> examination -> {free_room => free_room }

      # Doctor examines patient, doctor writes a document
      # Then patient is released, doctor files the document, and is again free to pick
      # another patient.
      #
      action examination(Doctor $dr, Patient $p) => (Document $document) {
        # take blood pressure
        $pressure = {upper => 117, lower => 76}
        
        # listen to heart
        $heart_rate = 70
        
        # assigns the output variable - it is an error not to do this
        $document = { 
          blood_pressure => $pressure, 
          heart_rate     => $heart_rate,
          patient        => $p[name]
        }
      }
    }

Now lets add that if there is ever two doctors waiting for patients, then they go off for a round
of golf. The winner goes home, and the loser returns to take care of patients.

    sequence [free[2]] -> golf -> { winner => drain, loser => free }
    action golf(Array[Doctor] $players) => (Doctor $winner, Doctor $loser) {
      # plays a round
      $winner = $players[0]
      $looser = $player[1]   # yeah, this is a rigged game :-)
    }
    
If we just add this to the plan, the result is not deterministic, a patient-doctor combination
may be picked if there are two doctors, or there may never be two doctors waiting at the same
time (we don't even know if there are ever two doctors in the clinic). There is also nothing
that prevents the doctor returning from a game to immediately go off on yet another game if
there is another doctor also free. We have not prevented all doctors from playing golf etc.

We can prevent doctors from playing golf if there are patients:

    sequence [free[2], !waiting] -> golf -> { winner => drain, loser => free }

If we want the doctors to hang around for 10 minutes before going golfing:

    function ten_minute_wait(Doctor *$doctors) {
      $doctors.any |$d| { queue_time($d) > 10*60 }
    }
    sequence [free[2], !waiting]
    -> select(free) ten_minute_wait
    -> golf -> { winner => drain, loser => free }
    
This means that at least one doctor must have waited for 10 minutes. The queue_time function is
a function that can access a queue meta parameter that indicates how long that object has been
in the queue (it is currently in).

If we want to keep track of that a doctor may only play one round per day we could keep track
of this in each instance of Doctor, but if we do not want this (or cannot modify the Doctor data type),
we need to keep track of this another way. We could schedule golf-tokens at the start of each day
with the name of the doctor - for the game to be enabled each doctor must also consume a
golf-token with the doctors name.

We could also make this merit based. A doctor must have seen at least 10 patients a given day to
be allowed a round of golf. We could do that by enqueuing the doctors name after each consultation
and require that 10 tokens are needed to produce a golf ticket. We can have a scheduled action
that clear the tokens at midnight. If we want to carry forward at most one ticket, we could have a ticket producing action that consumes examination credits to produce a single ticket.

    plan physicians_practice {
    
      input Doctor arriving_doctors
      type Credit = Struct[{name => String, count => Integer}]
      queue Credit exam_credit
      queue Doctor to_be_credited

      # A new credit is needed for an arriving doctor (assuming they only arrive once per day)
      # The doctor is then free, and there is a credit record
      arriving_doctors -> create_exam_credit -> { dr => free, credit => credit }
      
      # After examination, a copy of doctor is enqueued to calculate new credit
      sequence  examination -> { dr => to_be_credited }
      
      # Create a new credit for a doctor
      action create_exam_credit(Doctor $doctor) => (Credit $credit) {
        $credit = { name => $doctor[name], count => 0 }
      }
      
      # Increment the credit by one
      action increment_credit(Credit $credit) => (Credit $new_credit) {
          $new_credit = { name = $credit[name], count => $credit[count] + 1 }
      }
      
      # Predicate to find the correct credit record
      function matching_credit_record(Doctor $dr, Credit $credit) {
        $dr[name] == $credit[name]
      }
      
      # Match doctor to be credited with a credit record and increment it
      # then put it back into exam_credit
      sequence
        [{dr => to_be_credited}, {credit => exam_credit}]
        -> select(dr, credit) matching_credit_record
        -> increment_credit
        -> { new_credit => exam_credit }
        
      # to play a game of golf, the doctors must both have credit
      # the winner still goes home, and the looser gets a new credit starting at 0
      # irrespective of if there was additional credit
      #
      # If a doctor can only play once a day, then the doctor could be routed
      # to free instead (then there will be no credit record, and the doctor is not
      # eligible to play until doctor goes home and again arrives).
      #
      sequence [free[2], exam_credit, !waiting]
        -> select(dr, credit) must_have_credit
        -> select_aggregate(free) ten_minute_wait
        -> golf
        -> { winner => drain, loser => arriving_doctor }

      # Find a matching credit record, and check that there is enough credit
      #
      function must_have_credit(Doctor $dr, Credit $credit) {
        $dr[name] == $credit[name] and $credit[count] >= 10
      }

    
### TODO
 
 * name sequences, this allows them to be overridden in a derived plan ?
 * selection based on aggregate instead of each row (one of the rows must, at least three of
   the rows must, etc) see select_aggregate for an idea
   
   
Orchestration
===
So far, the creation of processes from plans, and the orchestration of plans have not been described. Clearly something is needed to be able to instantiate a process and to send information to it. A mechanism is also required to tell an orchestrator to start, stop and send information to a running process.

In order to do this; each Honeydew instance runs an Orchestrator. This orchestrator may be aware of a parent orchestrator. When an orchestrator is asked to perform a task, it may delegate this task to its parent.

A parent orchestrator may be remote, and the local orchestrator and the remote orchestrator communicates via proxies.

These are the primitives (functions):

    Process create_process(Plan plan, Hash[String, Any] initial_input_values)
    Process send(Process p, String input_name, Any value)
    Process send(Process p, Hash[String, Any] multiple_input_values)
    orchestrate(Process p)
    orchestrate(Plan p)
    
As a concrete example, we will use a 3-tiered application that consists of a db-server part, an application-server part and a client part.
The db-server part is a singleton, there can be multiple application servers, and multiple clients.
We want our automated system to spin up one db-server, and two application servers. On one of the application servers we want a service that acts as a client against the application service on the same host. For debugging and development reasons we also want to be able to run all three tiers on the same machine so we want to make the system configuration easy to compose out of reusable parts.

The Db-server clearly needs to make the "db_server" and "db_name" available to the application
servers. So we start there. There are two pieces of information; the hostname of the server
which is known as soon as we start provisioning this server for the purpose of becoming the
db server, and the name of the database that will be created which is known since one resource has
this information. Since the Plan we are going to execute runs on the agent, and the Catalog
contains all the resources, this information is available as soon as the agent starts processing
the catalog. 

    class three_tier_application {

      # A parameterized plan - the hostname is determine by the fqdn fact where this
      # plan will run, and the db_name is given when the plan is included in the catalog.
      # A plan is also a kind of resource, and has a title, which has a very natural fit
      # with the db_name parameter it needs.
      #
      plan db_server_plan {
        type db_info = Struct[{db_name => String, db_host => String}]
        output Db_info db_info
        
        # The default start point is redefined to be initialized with the title of the plan
        # resource which is the name of the db.
        # We could have used the $title directly in the action below, but then the action
        # would depend on the particular solution of using $title, this may not be the
        # case later and breaks the design rule of pure functions/actions.
        #
        queue start { add => $title }
        
        # We start with a very simple sequence - later we may want to do more; run
        # a warmup script and send information that the db-server is ready to service
        # traffic. That may signal other configuration / switches to be made in the overall
        # orchestration of the application.
        #
        sequence
          {db_name => start} -> produce_information -> { db_info => db_info }
        
        # This simple action takes the db_name as input, and produces a record
        # of hostname and db_name.
        #  
        action produce_information(String $db_name) => (Db_info $db_info) {
          $db_info = { 
            db_name => $db_name,
            db_host => $::fqdn,
         }
      }
    
      class db_installation {
        # the db packages are installed, services started etc.
      }
      
      class db_initialization($db_name) {
        # create instance of the db_server plan
        three_tier_application::db_server_plan { $db_name: })
        
        # creates a db with the given name, if it does not exists
        # initiates it with base data if db is empty
      }
      
      node the_db_server {
        include db_installation        
        class {
          db_initialization:
            db_name => 'the_app_db',
        }
        
        Class[db_installation] -> Class[db_initialization]
      }

When the above is executed - the agent has two plans to execute; the catalog plan which does
what the agent currently does (synchronizing the catalog), and the db_server plan. We have not yet
defined how the agent deals with these plans; which plans the node manages locally (e.g. the catalog), and which plans it manages remotely (e.g. the db_server plan).

The defaults are that the local orchestrator deals only with the catalog plan. All other plans
are handled by creating a process for them, and sending of information to the global orchestrator.

If we instead wanted to handle the orchestration of a co-located database client we need to do
more. First we look at a stand alone client.

This is a very straight forward construct if it were not for the two parameters that we
need from the db server. Essentially we want to do this:

    node some_client_node {
      db_client { 'the_client':
        db_name => $db_name,
        db_host => $db_host,
    }
    
    define db_client(String $db_name, String $db_host) {
    }

But where does the values for the two variables come from? The values will be available on
the agent at a future point in time (not when the catalog is produced). This is solved by
letting the references be future references - no special syntax is needed since it is known
if a reference is to a plan or not. We can thus write:

    plan db_client {
      input Db_info db_info
    }
    node some_client_node {
      include db_client
      
      db_client { 'the_client':
        db_name => $db_client::db_info[db_name]
        db_host => $db_client::db_info[db_host]
    }
    
    define db_client(String $db_name, String $db_host {
    }
    
The compiler when it evaluates the reference to `$db_client::db_info` knows that this is a plan
and that it cannot resolve this value when the catalog is built. Instead it records the value
as a future reference - internally this may be represented as an action that picks up the
values and pokes them into the resource that is wired to take place before the syncing of
that resources - i.e, the values of the resource are undefined in the catalog until the preceding
action has taken place. (This removes an issue regarding type checking of parameters since they
would otherwise have to always be of type Future[T] where T is the type that the parameter normally
accepts).

A catalog plan without any dependencies on other plans looks like this for a set of resources
R1, and R2, resource R1_1 depends on R1, and resource R1_1_2 depends on both
R1 and R2. The resources are of a type denoted with T<same number> (does not matter what the
actual types are) for this example. There are also 2 resources R10 and R11 that have no dependencies.

    plan sync_resources {
      # This is where all synchronized resources go
      #
      queue Resource synced

      # resources in the simple queue are synchronized and then done
      queue Resource simple {
        add_all => [T10[R10], T11[R11]]
        }

      action in_parallel { }

      sequence
        start -> in_parallel
        in_parallel -> sync_resources
        in_parallel -> r1
        in_parallel -> r2
              
      sequence
        r1 -> { resource => synced }
        r2 -> { resource => synced }
        r1 -> r1_1
        r1 -> r1_1_2
        r2 -> r1_1_2
      
      sequence
        { resource => simple } -> sync_resources -> { resource => synced }
        
      action sync_resources(Resource $resource) => (Resource $resource) {
        # this does what the agent currently does
        synchronize($resource)
      }
        
      action r1() => (T1 $resource) {
        $resource = synchronise(T1[r1])
      }
      action r2() => (T2 $resource) {
        $resource = synchronise(T2[r2])
      }
      action r1_1() => (T1_1 $resource) {
        $resource = synchronise(T1_1[r1_1])
      }
      action r1_1_2() => (T1_1_2 $resource) {
        $resource = synchronise(T1_1[r1_1_2])
      }
    }

The above implies that:

* queue a, b; a -> b, implies an action a_b that copies input to output
* action a, b; a -> b, implies a queue a_b that a produces to, and that b consumes from

These implied queues / actions makes it less noisy to write sequences.

Completing a Resource with a Future
---
If we take the catalog example with resource R1, R2, etc. and combine them with the 
DbClient example we get the following addition to the sync_resources plan:

     # action that combines promised values with the otherwise empty resource
     # and then synchronizes the result
     #
     action db_client(DbInfo $db_info, Db_client $resource) => (Resource $resource) {
       $resource[db_name] = $db_info[db_name]
       $resource[db_host] = $db_info[db_host]
       synchronize($resource)
     }
     
     # The db_client is also synchronized in parallel with "the rest", r1 and r2
     sequence
       in_parallel -> db_client
       
     # The sync_resources plan must have a Db_info as input
     input Db_info db_info
     
     # And the db_client needs this info
     sequence
       { db_info => db_info} -> db_client
       
The main plan
---
There is always a main plan. If there is only the resources to sync, this plan is:

     plan main {
       sequence
         start -> spawn_sync_resources -> end
       
       action spawn_sync_resources() {
         spawn sync_resources
       }
     }

This implies that a Plan[name] plays the same role as an action - but in contrast to an action
the execution of the plan is asynchronous. The same mapping applies of queues to parameters/inputs,
and mapping of outputs.

In order to handle the db_client which will be orchestrated externally, the default main
plan is generated as:

    plan main {
      # this spawns (creates) the sync_resources process ("runs the catalog")
      #
      action spawn_sync_resources() (Process[sync_resources] $sync_resources_proc){
        spawn sync_resources
      }

      # This spawns (create) the db_client process - and sends it to the orchestration
      # server - the process id is produced as output as we need to get the input of
      # this particular process' input (since we could have multiple database clients to
      # provision).
      #
      action spawn_db_client() => (Process[db_client] $db_client_proc){
        $pid = spawn(db_client)
        orchestrate(db_client)
      }

      action in_parallel {}
       
      sequence
        start -> in_parallel;
        in_parallel -> spawn_sync_resources;
        in_parallel -> spawn_db_client;
        # Take from the db_info process' db_info input and put it in the sync_resources_proc
        # db_info input.
        #
        {db_info => $db_client_proc::db_info} -> { db_info => $sync_resources_proc }
        
    }

In order to allow overrides of particular actions - the main process is actually generated like
this:

    plan main inherits _main {
    }
    
And the _main plan contains everything that is generated automatically. The user may override
the plan called main (by redeclaring it) and override specific actions - e.g.

    plan main inherits _main {
    
      action spawn_db_client() => (Process[db_client] $db_client_proc) {
        $db_client_proc = spawn(db_client)
        send($pid, db_info, {db_host => localhost, db_name => 'the_db'})
      }
    }

Which, either for local configuration purposes, or for debugging manually creates a
Db_info struct and sends that as input to the db_client process.

Orchestration Implementation
---
The orchestration function is implemented as a plan. When an agent is running with an
orchestration server, the plan is simply a queue that terminates in the orchestration server.

The type of the queue is Process[P] which implies that both the orchestrator and the orchestrated
share the definition of the plan P. Thus, they know about the inputs and outputs of this process.

This means, that orchestration is just another plan with Process[P] instances as input.

How does the orchestration plan get populated with the action that takes the output from
the db_server and sends it to every db_client instance that requires it?

We do this in the three_tier_application plan. It consists of several plans:

* The db_server plan - included on the db_server
* The db_client plan - included on the application server (or multiple app servers)
* The app_client plan - included on every client node         
* The orchestration plan - runs on the orchestration server

The purpose of the orchestration plan is to define how the other plans are wired together.
The orchestration plan has one input per Plan it orchestrates.

     plan orchestration {
       input Plan[Db_client] db_client
       input Plan[Db_server] db_server
       input Plan[App_server] app_server
       input Plan[App_client] app_client
       
     }

These input queues receive the requests from agents to orchestrate the plans. We can get from
those processes' outputs and post to their inputs. Since we want the db_server output to
be available "for ever" and for any application server that asks for it (and likewise for
the application server vis-à-vis its clients).

    queue Db_info db_info { latch => true }
    queue Appserver_info appserver_info { latch => true }
    
We then need to feed the db_server's db_info output in the db_info queue (where it is latched).

    sequence
      db_server => {db_info => db_info}
      
And to the same for the application server

    sequence
      app_server => {appserver_info => appserver_info}
      
We need to feed the db_info into every db_client process.

    sequence
      [db_info, db_client] -> handle_db_client -> drain
      
    action handle_db_client(Db_info $db_info, Process[Db_client] $db_client_proc) {
      send($db_client_proc, db_info, $db_info)
    }

And likewise for the application client

    sequence
      [appserver_info, app_client] -> handle_app_client -> drain
      
    action handle_app_client(Appserver_info $app_info, Process[Appserver_client] $app_client_proc) {
      send($app_client_proc, app_info, $app_info)
    }

The full orchestration plan is now:

     plan orchestration {
       input Process[Db_client] db_client
       input Process[Db_server] db_server
       input Process[App_server] app_server
       input Process[App_client] app_client

       queue Db_info        db_info        { latch => true }
       queue Appserver_info appserver_info { latch => true }
       
       sequence
         db_server -> {db_info => db_info};
         app_server -> {appserver_info => appserver_info};
         [db_info, db_client] -> handle_db_client -> drain;
         [appserver_info, app_client] -> handle_app_client -> drain

       action handle_db_client(Db_info $db_info, Process[Db_client] $db_client_proc) {
         send($db_client_proc, db_info, $db_info)
       }

       action handle_app_client(Appserver_info $app_info, Process[Appserver_client] $app_client_proc) {
         send($app_client_proc, app_info, $app_info)
       }
     }

Which is included in the three_tier_application plan
    
    plan three_tier_application {
      # Struct with information how to connect to a database server
      type db_info  = Struct[{db_name => String, db_host => String}]
      
      # Struct with information how to connect to an application server
      type app_info = Struct[{app_host => String}]

      # A parameterized plan - the hostname is determine by the fqdn fact where this
      # plan will run, and the db_name is given when the plan is included in the catalog.
      # A plan is also a kind of resource, and has a title, which has a very natural fit
      # with the db_name parameter it needs.
      #
      plan db_server_plan {
        output Db_info db_info
        
        # The default start point is redefined to be initialized with the title of the plan
        # resource which is the name of the db.
        # We could have used the $title directly in the action below, but then the action
        # would depend on the particular solution of using $title, this may not be the
        # case later and breaks the design rule of pure functions/actions.
        #
        queue start { add => $title }
        
        # We start with a very simple sequence - later we may want to do more; run
        # a warmup script and send information that the db-server is ready to service
        # traffic. That may signal other configuration / switches to be made in the overall
        # orchestration of the application.
        #
        sequence
          {db_name => start} -> produce_information -> { db_info => db_info }
        
        # This simple action takes the db_name as input, and produces a record
        # of hostname and db_name.
        #  
        action produce_information(String $db_name) => (Db_info $db_info) {
          $db_info = { 
            db_name => $db_name,
            db_host => $::fqdn,
          }
        }
      }
      
      # This plan produces an App_info struct with the fqdn of the Application Server
      # host in a manner similar to how the database server is handled.
      #
      plan app_server {
        output App_info app_info
        sequence
          start -> produce_information -> {app_info => app_info}
        action produce_information => (App_info $app_info) {
          $app_info = { app_host => $::fqdn }
        }  
      }

      plan db_client {
        input Db_info db_info
      }

      plan appserver_client {
        input Appserver_info app_info
      }
     
     
      # This defines the plan for how the three tiers are orchestrated
      #
      plan orchestration {
        input Process[Db_client] db_client
        input Process[Db_server] db_server
        input Process[App_server] app_server
        input Process[App_client] app_client

        queue Db_info        db_info        { latch => true }
        queue Appserver_info appserver_info { latch => true }
        
        sequence
          db_server -> {db_info => db_info};
          app_server -> {appserver_info => appserver_info};
          [db_info, db_client] -> handle_db_client -> drain;
          [appserver_info, app_client] -> handle_app_client -> drain 

        action handle_db_client(
          Db_info            $db_info, 
          Process[Db_client] $db_client_proc
          ) {
          send($db_client_proc, db_info, $db_info)
        }

        action handle_app_client(
          Appserver_info            $app_info, 
          Process[Appserver_client] $app_client_proc
          ) {
          send($app_client_proc, app_info, $app_info)
        }
      }
    }
    
    class myapp {
    
      class db_installation {
        # the db packages are installed, services started etc.
      }
      
      class db_initialization($db_name) {
        # create instance of the db_server plan
        three_tier_application::db_server_plan { $db_name: })
        
        # creates a db with the given name, if it does not exists
        # initiates it with base data if db is empty
      }
    
      class db_server_role($db_name = 'the_app_db') {
        # include the db_server plan
        plan { myapp::three_tier_application::db_server: }

        include myapp::db_installation        
        class {
          myapp::db_initialization:
            db_name => $db_name,
        }
        
        Class[myapp::db_installation] -> Class[myapp::db_initialization]
      }
      
      class db_client_role {
        # include the db_client plan
        plan { myapp::three_tier_application::db_client: }
        # want to write a config file with the information
        # MERDE! wants to use a template
        file { 'somewhere': contents => template(...) }
        
        # The db client package is installed etc.
      }
      
      class app_server_role {
        include db_client_role
        # include the app server plan
        plan { myapp::three_tier_application::app_server: }
      }
      
      class app_client_role {
        # include the app client plan
        plan { myapp::three_tier_application::app_client: }
        
        # use the values from the plan
        notify { 'app_server_name': 
          message => 
          "The app server is ${myapp::three_tier_application::app_client::app_info[app_host]}"
      }

    }
    
And on the various nodes:
        
      node the_db_server {
        include myapp::db_server_role
      }
      
      node the_app_server {
        include myapp::app_server_role
      }

      node /*.client.company.com/ {
        include myapp::app_client_role
      }

Issues Found:

* references to plan values - which instance, assumes there is only once instance of each
  type of plan
* reference to future values can appear anywhere
  * must be able to use templating on agent (or, how to write a complex file?)
  * reference these variables in any resource value expression - e.g. user defined resources that
    pass on the future values. What if logic is conditional and include different resources
    based on the promise? (That breaks the entire design since planning can then not be made server side). They could be viewed as agent side generated resources though...


TODO
---
 * The above example introduced parameterized plan. The parameters must be given when the
   plan is orchestrated.
* How is the three tier example abstracted, so that new user specific three tier plans are easy
  to construct?
* The term in_parallell is used in sequences - it is not defined anywhere
    

   

 