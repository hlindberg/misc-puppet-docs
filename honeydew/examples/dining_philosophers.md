Dining Philosophers
---
The dining philosophers problem is an example problem used to illustrate synchronization
and techniques for resolving them. The problem was formulated in 1965 by Djikstra.

> Five silent philosophers (P) sit around a table with a bowl of spaghetti.
Forks are placed between each pair of adjacent P. Each P must alternate between
thinking and eating. A P can only eat when having both left and right forks. Each fork
can only be held by one P at a time. After eating P puts down both forks on the table. An infinite amount of spaghetti and stomach space is assumed.

## Example 1 - a naive implementation

In this first naive implementation, we rely on the identity of a set of philosophers to calculate
which fork is the fork to the left and right of a P. A fork is represented by an integer
(1-5) where fork 1 is between P1 and P2, and fork 5 is between P5 and P1. It is then simple
to calculate left and right forks using a modulo operation.

Example (Deadlocking Dining Philosophers)

~~~
actor dphil {                   # dining philosopher
  $n = 5                        # cater for 5 philosophers (bad design on purpose)
  public Integer id             # philosopher id (used to derive fork number)
  public left() { id }          # left fork number
  public right() { id % n + 1 } # right fork number
  public hungry() { true }      # a phil is always hungry
}

Actor dining_table {
  # cater for 5 philosophers
  $n = 5
  queue Dphil   thinking { entries => Integer[1,$n].map |$x| { Dphil({id => $x}) }}
  queue Dphil   has_left, has_right, eating
  queue Integer forks { entries => *Integer[1, $n] }
    
  action get_left {
    $x <- thinking where $x.hungry()
    $f <- forks    where $f == $x.left()
    $x -> has_left
  }

  action get_right {
    $x <- has_left where $x.hungry()
    $f <- forks    where $f == $x.right()
    $x -> has_right
  }
  
  action eat {
    $x <- has_right
    $x -> eating
  }
  
  action think {
    $x         <- eating  # perhaps delayed 1s, or eats very quickly :-)
    $x         -> thinking
    $x.right() -> forks
    $x.left()  -> forks
  }
}
~~~

### What is wrong with example 1 ?

If you have not noticed already, the implementation in example 1 will deadlock. This 
happens because all philosophers will take their higher numbered fork first (except the first P who picks up 1 before the highest numbered fork). No P will give up
a fork, and they are then all waiting for their right fork.

There are different ways to solve this:

* timing out
* hierarchical order
* arbitrator
* chandry/misra algorithm

In the implementation, there is no problem of starvation since all philosophers have a uniform behavior - they eat instantaneously, and after having eaten they return last to the queue of
thinking philosophers where there will always be a waiting/thinking philosopher that is hungry. (That is as, soon as the deadlock problem is solved).

In a real situation philosophers may eat/think and become hungry at different intervals and
the implementation in example 1 will not suffice as it contains nothing that prevents
starvation (for which there are a number of different solutions where the chandry/misra algorithm
is one).

We also have several implementation related problems that we save to discuss for the 
final Chandry/Misra implementation.

#### Timing out

A naive solution is to make a P return a held single fork after a timeout. This avoids 
the deadlock, but will suffer from live lock since all philosophers can arrive at exactly the same time (they all take one fork, then all give up at the same time, then all try again at the same time). The live lock problem can be avoided by randomly backing off (this is what Ethernet
does when there are collisions). While this scheme is simple to implement it does less well under high contention.

Time outs are modeled by adding an ` after <time>` to an input arc. We can therefore solve the deadlock by adding one action:

~~~
action give_up {
  $x <- has_left after 1m
  $x.left() -> fork
}
~~~

Which will release a held left fork after 1 minute. We also need to prevent the live lock by
making a P wait a random time before attempting to get the left fork:

~~~
action get_left {
  $x <- thinking where $x.hungry() after random(1m)
  $f <- forks    where $f == $x.left()
  $x -> has_left
}
~~~

#### Using a Hierarchical solution

This deadlock can be avoided (as Djikstra found) by introducing a partial order to the forks.
If everyone picks up their lower numbered fork first the deadlock is avoided since the last
P will have a lower number fork to the right instead of to the left.

In general practice however, this solution is not efficient since such a hierarchical lock
requires that that all higher priority resources must be released to obtain a lower level resource.

The above example is easily changed to hierarchical locking by modifying the functions `left`
and `right` to `first` and `second`, and modifying how the fork number is calculated.

~~~
first()  { id - 1 * (id - id % n) / n }
second() { id + 1 - 2 * (id - id % n) / n }
~~~

Which is efficient but neither easy to construct nor read. Instead we can do like this (and keep
the `left` and `right` functions, but only to calculate the smaller and larger number:

~~~
first()  { min(left(), right()) }
second() { max(left(), right() }
~~~

The actions `get_left` and `get_right` must be changed, and the queues for the intermediate
states must also be changed:

~~~
  queue Dphil   has_first, has_second, eating

  action get_first {
    $x <- thinking where $x.hungry()
    $f <- fork     where $f == $x.first()
    $x -> has_first
  }

  action get_second {
    $x <- has_left where $x.hungry()
    $f <- fork     where $f == $x.second()
    $x -> has_second
  }

~~~

#### Arbitrator Solution

Another solution is to let the philosophers ask for permission to pick up a fork. All requests
that does not cause a deadlock can be honored.

A deadlock can be detected for the table by adding a function:

~~~
actor dining_table {
  ...
  public will_deadlock() { hasLeft.count == $n - 1 }
}
~~~

We can then make the philosophers lose their appetite when they see the distasteful deadlock
situation. In order to do so, a P must be aware of the table they are sitting at and we change
the construction of a philosopher to include the table, 

~~~
Dphil({id => $x, table => $table})
~~~

and we modify the function `hungry` like this:

~~~
public hungry { !table.will_deadlock() }
~~~

We could instead detect when there is an actual deadlock, and then return one of the
philosophers to `thinking` instead of preventing the last P (causing the deadlock) to not take the last fork. This is a cleaner separation of concerns (but left as an exercise since there is an even better solution).

#### Chandry/Misra solution

In this solution, one rule of the original problem is broken as the philosophers need to
communicate with their neighbors (in the original they are silent). This solution is better because it allows for an arbitrary number of philosophers and shared resources and while running no arbitrator/controller is involved in the decision making which makes it possible to more efficiently distribute the running plans.

The algorithm was described by Chandy and Misra in 1984:

1. For every pair of P contending for a resource, create a fork and give it to the P with lower id.
2. A fork can be clean or dirty, initially, all forks are dirty
3. When a P wants to eat forks are obtained from the contending neighbors for each fork P does not have
4. A P receiving a request for a fork keeps a fork that is clean, but gives away one that is dirty
5. A P that gives away a fork cleans it before giving it away
6. When a P is done eating both forks become dirty
7. If there are requests outstanding when a fork becomes dirty, the P cleans it and gives it away

When implementing this solution - lets also fix the general implementation problems:

* The original dining_table created the philosophers - this makes it difficult to have different kinds of philosophers (with different timing of thinking/hungry/eating) - i.e. what we might have in a real implementation.
* We can not have philosophers with a different overall plan, since the table actor models thinking/eating/has_left/has_right - it would be more natural to let a philosopher be in charge of these internal state transitions.
* All philosophers are initially created, they cannot enter at arbitrary times, and they cannot leave.

The better, Chandry/Misa based solution is shown in example 2

### Example 2 - Chandry/Misa solution

We start by creating an actor that simply creates a table for 5, and adds 5 philosophers.
The rest of the implementation has clear separation of concerns.

~~~ 
actor dining_philosophers {  # Sets up a a scenario with 5 philosophers
  $n = 5
  $table = DiningTable({ seats => $n })
  queue Philosopher philosophers {
    entries => Integer[1, $n].map |$x| {
      Phil({id => $x, table => $table})
    }
  }
  
  action seat {
    $p  <- philosophers[$n]  # consume 5
    *$p -> $table.arrived    # 5 arrive to be seated at table
  }
}
~~~
The type system is used to create Fork tokens of two kinds; dirty and clean. We do not
keep track of the state or identity of the forks. We could, and then model them as stateful
actors. We could also have used integers 1 and 2 for clean and dirty fork respectively

~~~
abstract type Fork inherits Symbolic {}
type DirtyFork inherits Fork {}
type CleanFork inherits Fork {}

~~~

The dining table is now generic - it only keeps track of the seating of philosophers
and handing out the initial fork (one per P). The table requires a value for `seats` and
there must be a minimum number of 2 since the algorithm does not work for the special case
of a single P.

The table arranges Ps in a double linked list; each P knows about the P on its left and
right. The left/right information is held in queues to make it possible to dynamically
alter the linked list. An arriving P is always seated to the left of the last already seated P.

~~~

actor table {
 Integer[2] $seats  # Allows capacity >= 2
 queue Phil arrived, seated { capacity => $seats }
 
 # Upon arrival, a p is seated and introduced to its neighbors with which the p
 # contents with for forks.
 #
 action seat {
   $p                <- arrived

   # Unlink first and last
   Optional[Phil] _  <- seated.first.right
   Optional[Phil] _  <- seated.last.left

   # Add a fork
   DirtyFork()       -> $p.forks
   
   # Link the p to neighbors
   seated.last       -> $p.right
   seated.first      -> $p.left
   
   # Link neighbors to p
   $p                -> seated.first.right
   $p                -> seated.last.left
   
   # seat p
   $p                -> seated
 }
}

~~~
A philosopher is now in charge of its own state. We use queues to model the holding of
forks, requests for forks by neighboring philosophers, and the philosopher to the left
and right.

We maintain the philosophers state of thinking/eating as well as intermediate state
describing having outstanding requests using a shorthand notation of `state` (which is
an enumeration of queues of capacity 1 of the same type as the plan itself (i.e. `Phil`) and that is read only if made public. Consumption and production to such state queues are always to/from `self`.
A plan can have multiple state entries - in each entry, the plan may only be in one of the given states at any given time. When created, the plan enters the first given state. Thus, in this
implementation a newly created Phil is both `thinking` and `not_hungry`.

~~~

plan Phil {
  public queue Fork forks
  public queue Phil requesting_philosopher
  public queue Phil left
  public queue Phil right
  
  # A 'state' is a shorthand for a queue of self with capacity 1, the first listed state is
  # the initial state. It is externally read only if made public. Thus, a p is initially
  # thinking.
  #
  public state thinking, eating
  public state not_hungry, hungry, left_requested, right_requested
  
  private $two_dirty_forks = [DirtyFork(), DirtyFork()]
  
  # If p has two clean forks, p will be eating
  #
  action eat {
    $p  <- right_requested
    $f  <- forks[2] where $f =~ CleanFork  # Note: [2] picks 2 forks
    $p  -> eating
  }
  
  # If p is eating, p puts down two dirty forks, is no longer hungry and
  # returns to thinking.
  #
  action think {
    $p                  <- eating
    * $two_dirty_forks  -> forks  # Note: * $two_dirty_forks puts two dirty forks
    $p                  -> not_hungry
    $p                  -> thinking
  }

  # p becomes hungry after >= 1s of not being hungry (p can still think)
  action hunger {
    $p <- not_hungry after 1s
    $p -> hungry
  }
  
  action request_left_fork {
    $p                          <- hungry
    left.requesting_philosopher <- $p
    $p                          -> left_requested
  }

  action request_right_fork {
    $p                           <- left_requested
    right.requesting_philosopher <- $p
    $p                           -> right_requested
  }
  
  # p gives a clean fork to a requesting p by consuming a dirty held fork
  # and producing a clean fork to the requestor
  #
  action give_up_fork {
    $p           <- requesting_philosopher
    _            <- forks where $f =~ DirtyFork
    CleanFork()  -> $p.forks
  }
}

~~~

There are naturally other ways of implementing the algorithm.

There is one flaw in this implementation - did you spot it?
(The initial state where each p holds a DirtyFork means that a p can give it away
to either the p on left or right - that is not correct per the problem definition). Correcting the  example is left as an exercise.

Setting up a table and simulating driving philosophers is left as an exercise. So is, making philosophers leave after a given time.

  