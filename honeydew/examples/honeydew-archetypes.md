The 7 archetypes
---

There are seven archetypical constructs

* sequence
* conflict (or)
* confusion
* concurrency
* synchronization
* merge
* priority / inhibit

This document shows how each is expressed in Puppet using the Honeydew grammar. The examples
are writen using queues internal to the plan, but these could also be inputs/outputs of the plan.
The archetype examples are also written without passing any values in/out of the actions - the
actions are simply triggered. This is done to focus on the principles of action scheduling and token
consumptions. 

### Sequence

A specification of three actions in sequence:

    plan sequence {
      flow { start -> action1 -> action2 -> action3 -> end }
      
      action1 { }
      action2 { }
      action3 { }
    }

### Conflict (or)

A specification where the logic can take one or several paths:

    plan conflict {
      queue a
      queue b
      queue c
      
      flow { start -> action1 -> a }
      flow { start -> action2 -> b }
      flow { start -> action3 -> c }
      
      action1 { }
      action2 { }
      action3 { }
    }

Here, multiple actions are enabled at the same time. One token in `start` can be consumed by
either one of the actions.

> In comparison: In CPN one of the transitions/actions is selected non-deterministically.

In Honeydew, the firing will take place in round-robin fashion where the selected action will be the one with the longest waiting time since its last firing.
(Thus, at any given time there are more than one enabled action, the one waiting the longest
to fire is selected). In a tie, the transition with the lexicographically earlier name is
selected.

In the example, `action1` will win, since there is a tie (all have waited the same amount of time (0), and action1 is lexicographically first.

### Concurrency

A specification where an action is followed by actions in parallel:

    plan concurrency {
      queue a
      queue b
      
      flow { start -> action1 -> [a, b] }
      flow { a -> action2 -> drain }
      flow { b -> action3 -> drain }
            
      action1 { }
      action2 { }
      action3 { }
    }

    
Here, each time `action1` fires, a copy of its input (value from start) is placed in `a`, and `b`, which causes the remaining actions to fire (in this example the produced output is irrelevant).

### Synchronization

A specification where an action consumes more tokens than it produces, thereby synchronizing parallell threads (a reduction if seen as a computation):

    plan synchronization {
      queue a
      queue b
      queue c
      
      flow { a,b] -> action1 -> c }
      
      action1 { }
    }
    
Here, `action1` fires when there is a token in each of the queues `a`,and `b`, and it produces
the synchronized result in `c`.

### Confusion

A specification that depends on the qualities of the input queues to be deterministic:

    plan confusion {
      queue a
      queue b

      flow { a     -> action1 -> drain }
      flow { [a,b] -> action2 -> drain }
      flow { b     -> action3 -> drain }
            
      action1 { }
      action2 { }
      action3 { }
    }
    
Since there is no guarantee that tokens appear in `a` and `b` at the same time it is non deterministic which one of the actions will fire. (Only one of them can fire; `action2` if there is a token in both `a` and `b`, and one of the other actions if only `a` or `b` has a token).

This is non deterministic in Honeydew in general too. However the round robin scheduling of each queue's outputs is used to select a winning action. This makes the case when there is a steady supply of tokens in both `a` and `b` deterministic. In the first round `action1` wins over `action2` for a token from `a`, `action2` cannot fire, and `action3` thus wins over `action2` for a token from `b`. The next round, `action2` wins over `action1` for a token from `a` because it has waited longer, and it also wins over `action3` for a token from `b` for the same reason. The cycle then repeats.

In practice a construct like this requires specification of time, since determinism is only achieved if tokens for `a` and `b` are in infinite supply or are always produced in tandem in the same round. A construct involving time would hold off for a given period of time before selecting one of the three actions, thus making it possible to configure how long the plan waits for both an `a` and a `b` before processing an individual `a` or `b`.

### Merge

A specification where the result of two parallell threads are merged into a single thread proceeding with the results in sequence:

    plan merge {
      queue a
      queue b
      queue c
      
      flow { a -> action1 -> c }
      flow { b -> action2 -> c }
            
      action1 { }
      action2 { }
    }

    
Here, the token streams are not synchronized, their paths are simply merged (they were earlier
executed in parallel, but are now merged into a sequence). If both transitions fire,
there are two tokens in `c`. The order in which `action1` and `action2` fires depends on how tokens arrive in the queues `a` and `b`.
    
### Priority / Inhibit

    plan inhibit {
      queue a
      queue b
      
      flow { a -> action1 -> drain }
      flow { unless b a -> action2 -> drain }
            
      action1 { }
      action2 { }
    }
    
Here `action1` is enabled if there is a token in `a`, action2 is enabled if there is
a token in `a` and no token in `b`. (Which transition to fire depends on if there is 
a guard / select, or by round robin selection).

An inhibitor does not pass on any value / color. An inhibitor may have
constraints and it inhibits if the resulting constraints applied to any existing tokens
results in an empty set).

    flow {
      unless b where b =~ Enum[warning]
      a -> action2
    
Here, `action2` is inhibited if there is a string with value 'warning' in queue `b`. No value is
every consumed from `b`.

No token is ever consumed by an inhibitor arc.
    
