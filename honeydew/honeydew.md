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
Places (that contains tokens), Transitions (that consumes tokens
in input Places, performs some work and produces tokens in output Places).
Places and Transitions are connected via Arcs.

P -> T

An arc from P to T, consumes one or more tokens from P.

Tokens have Type, and as tokens flow through the network they are said to color the
Places and Transitions. In most cases "color" is synonym to "type".

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
to a corresponding (O)PN. (This makes it possible to to design and validate designs. Automatic translation may be possible, and it may be possible to transform a Honeydew design to PN form for analysis - this is however a separate topic).

The two main concepts are `Plan` and `Process`. A `Plan` corresponds to an executable computer 
program, and a `Process` corresponds to an instance of an executing `Plan`.

A Plan is reminiscent of a function definition - it has inputs and outputs represented by
typed places and a body of logic (consisting of transitions with associated actions). A Plan is also
reminiscent of a command line utility into which it is possible to pipe input (stdin) and get output on one (stdout), or multiple streams (stdout, stderr).

    
### Example - Physicians Practice

A Physician's Practice has a waiting room where patients enter. A doctor consults with
a patient when the doctor is free. A doctor documents a consultation when it is over,
the patient is then done, and the doctor is free to consult with the next patient.

    Place waiting[Patient], free[Doctor]
    Place consultation[Struct[{p=>Patient, dr=>Doctor}]]
    Place done[Patient]
    
    Transition next, document
    
    next(waiting, free)      => consultation
    document(consultation)   => [done(Patient), free(Doctor)]
    
When type alone cannot identify each data element, they must be tagged with a "color". If
both doctors and patients were identified by strings we would have to color them.

    Place waiting[String], free[String]
    Place consultation[{p=>String, dr=>String}]
    Place done[String]
    
    Transition next, document
    
    next(p = waiting, dr = free)      => consultation(p, dr)
    document(consultation)            => [done(p), free(dr)]

### Transition

A Transition is a function that takes n-tokens from each input place, performs some action
and produces n-tokens in each output place. The input type of the transition function is
a Struct combining the type of each input. If more than one token is taken from a place
the type for that contribution is Array[place-type].

The transition may transform the input, and may produce an output structure of different type.

A transition fires when all of its inputs are enabled.
An input is enabled if the requested n-tokens are available, and these token meet the input criteria
of an additional optional guard type, and boolean guard expression. The oldest available tokens
meeting the criteria are selected.


Honeydew Language
---
This is tentative syntax, no attempts have been made yet to implement this as part of the
Puppet Programming Language. 

    Plan
      : 'plan' NAME '{' expressions += PlanExpression* '}'
      ;
  
    PlanExpression
      : PlaceDeclaration
      | InputDeclaration
      | OutputDeclaration
      | TransitionDeclaration
      | SubplanDeclaration
      | Arc
      ;
  
    PlaceDeclaration
      : 'place' NAME ('[' Type ']')? ('=' max = INTEGER)?
      ;
      
    InputDeclaration
      : 'input' NAME '[' Type ']' ('=' max = INTEGER)?
      ;
      
    OutputDeclaration
      : 'output' NAME '[' Type ']' ('=' max = INTEGER)?
      ;
        
    TransitionDeclaration
      : 'transition' NAME
      # TODO: Action, parameters, etc
      ;

    SubplanDeclaration
      : 'subplan'
    Arc
      : transition = NAME '(' TransitionInputs ')' SelectClause? '=>' TransitionOutputs
      ;
    
    TransitionInputs
      : inputs += TransitionInput (',' inputs += TransitionInput)*   
      ;
      
    TransitionInput
      : ((inhibit ?= '!') | (color = NAME))? 
        place = NAME ('[' type_filter = Type ']')? ('=' pick=Range)?
      ;
      
    TransitionOutputs
      : outputs += TransitionOutput
      | '[' outputs += TransitionOutput (',' outputs += TransitionOutput)* ']'
      ;
    
    TransitionOutput
      : (color = NAME)? place = NAME ('[' type_filter = Type ']')? ('=' count=INTEGER)?
      # TODO: Where, if color is given or combined type (use transition name?)
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

When a transition checks if it can be fired, it picks tokens from its input places
constrained by the input specification (the number and types of tokens to pick). When these
constraints can be satisfied, the optional select clause is given each result from a
cartesian product of the inputs sorted so that the oldest combination appears first (i.e. the combined age of the inputs). The select clause may refer to the inputs by the given colors
(colors must be given in order to reference the inputs).

The select expression `select oldest` is the default and does not have to be specified, it
simply selects the oldest combination that meets the constraints. It may be spelled out for
clarity.

A `select best` expects the following `Selector` expression to produce a ranking per given
row. The returned value must be `Numeric`, and the row with the highest value is selected.
All rows are fed to the selector expression before one is picked.

A `select` without the keyword 'best' expects the selector to produce a `Boolean` (or it is an
error), the row that first causes the selector expression to produce `true` is picked (and the
remaining rows are ignored). The rows are always presented with the oldest combination first.

The selector is either a function call to a named function. The arguments are the names
of the colors/aliases given to the inputs, possibly with a reference to a detail in the given
argument - i.e. doctor[speciality] (if a Doctor has a speciality attribute).

If the selector is specified with a block expression, the colors are bound to variable names
(e.g. $doctor, $patient).


As an example, if a Doctor has a speciality (e.g. 'cardiology') and there is a patient waiting
that needs a cardiologist, this combination of doctor/patient is given a higher score.

    next(doctor free, patient waiting) select best {
      if doctor.speciality == patient.specialist
        { 2 }
      else
        { 1 }
    } => consultation

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

    place a, b, c
    transition do1, do2
    
    do1(a) => b
    do2(b) => c

### Conflict

    place a, b, c, d
    transition do1, do2, do3
    
    do1(a) => b
    do2(a) => c
    do3(a) => d

Multiple transitions are enabled at the same time. In CPN one of the transitions is
selected non-deterministically, in Honeydew, the firing will take place in round-robin fashion where the selected transition will be the one with the longest waiting time since its last firing.
(Thus, at any given time there are more than one enabled transition, the one waiting the longest
to fire is selected). In a tie, the transition with the lexicographically earlier name is
selected.

### Concurrency

    place input, a,b,c
    transition do1, do2, do3, do4
    
    do1(input) => [a,b,c]
    do2(a)     => ...
    do3(b)     => ...
    do4(c)     => ...
    
Each time the transition do1 fires, a copy of its input is placed in a, b, c, which causes
the remaining transitions to fire. (Where the produce output is irrelevant).

### Synchronization

    place a,b,c,d
    transition do1
    
    do1(a,b,c) => d
    
The transition do1 fires when there is a token in each of the places a,b,c, and it produces
the synchronized result in d.

### Confusion

    place a, b
    transition do1, do2, do3
    
    do1(a)   => ...
    do2(a,b) => ...
    do3(b)   => ...
    
Since there is no guarantee that tokens appear in a and b at the same time it is non deterministic
which one of the transitions will fire. (Only one of them can fire; do2 if there is a token in
both a and b, and one of the other transitions if only a or b has a transition).

This is non deterministic in Honeydew; the round robin scheduling of each place's outputs will
be used to select a winning transition. 

### Merge

    place a
    transition do1, do2, do3
    
    do1(...) => a
    do2(...) => a
    do3(...) => a
    
The token streams are not synchronized, their paths are simply merged (they were earlier
executed in parallel, but are now merged into a sequence). If all three transitions fire,
there are three tokens in a.
    
### Priority / Inhibit

    place a, b
    transition do1, do2
    
    do1(a) => ...
    do2(a, !b) => ...
    
Transition do1 is enabled if there is a token in a, transition do2 is enabled if there is
a token in a and no token in b. (Which transition to fire depends on if there is 
a guard / select, or by round robin selection).

An inhibitor arc has undef value an no color/variable is bound. An inhibitor arc may have
constraints and it inhibits if the resulting constraints applied to any existing tokens
results in an empty set).

    do2(a, !b[Enum[sesame]]
    
Here, do2 is inhibited if there is a string with value 'sesame' in place b. 

No token is ever consumed by an inhibitor arc.

Transition Rules
---
A transition is enabled when (and only when):

* All input arcs are enabled
* All output arcs are enabled
* An input arc is enabled when there it satisfies the constraints (type) and count
* An output arc is enabled when the place it targets has spare capacity
* No disabling/inhibiting arc is enabled
 
    
Types
---
Additional types

* Unit (an anonymous non Undef object) may be of value
* Plan, parameterized by its inputs and outputs (name and type) - alternatively also a
  reference to a named plan - e.g. Plan[b],
  Plan[{input => {a => Integer, b=>String}, output=>{result => String}]
  
TODO
---
### Drain

There should be one place called drain at all times. This is a /dev/null. It simply forgets
the tokens that end up there. (It is an error to have a transition without any outputs).

While a transition without outputs could be taken as a drain (with possible side effects), it
is expected that it is far more common to make an error by not connecting output. With a drain,
this is explicit.

### Arc to place with guard?

Should there be a guard on the transition's output arcs? It should be possible to pick a color,
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

* A place that yields - thus allowing plans to be piped?
* A place that fails?
* A place that means "done", not caring if there are tokens in other places

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
      place start, end
      transition apply
   
      apply(start) => end
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