The Sleeping Barber Problem
---

> A barbershop has one barber that is sleeping when not shaving a customer. An arriving
> customer goes directly to the one barber chair if it is free afer having woken up the barber.
> If the barber chair is occupied, the customer waits in the waiting room. If the waiting room is 
> full, the customer leaves. Before going back to sleep the barser checks if the waiting room is 
> empty, and if not services the next customer.

The problem here is that all activities take an unknown amount of time; customer sees someone is getting a shave and goes to the waiting room, the barber finishes before the customer enters the waiting area, and goes to sleep. Customer then waits for ever on barber.

If we first ignore the problem's description that a customer goes directly to the barber chair if it
is free, the implementation is a simple producer/consumer problem:

~~~
type Customer inherits Symbolic {}
type Barber inherits Symbolic {}

plan barbershop {
  public queue Customer arriving { capacity => 5 }
  queue Barber   sleeping { entries => new Barber }
 
  action shave {
    b <- sleeping
    c <- arriving
    b -> sleeping
  }
}
~~~

Here, the barber always goes back to sleep after each shave. A customer never goes directly
to the barber chair.

If we add the details of arriving; going directly to the barber chair or waiting, and
that the barber changes state between sleeping and shaving we get the following.

~~~
type Customer inherits Symbolic {}
type Barber inherits Symbolic {}

plan barbershop {
  public queue Customer arriving { capacity => 25 } # the sidewalk outside the shop
  queue Customer waiting  { capacity => 5 }
  queue Customer chair    { capacity => 1 }
  queue Any      leaves   { ttl => 0 }       # self draining queue
  queue Barber   sleeping { entries => new Barber }
  queue Barber   shaving
 
  action leave_if_full {
    c <- @1s arriving # waits 1 second then leaves
    c -> leaves
  }
  
  action enter_barber_chair {
    c <- arriving
    c -> chair
  }
  
  action enter_waiting_room {
    c  <- arriving
    !! <- chair     # requires chair to be occupied
    c  -> waiting
  }
  
  action seat_next {
    chair <- waiting
  }
  
  action wake_up {
    b <- sleeping
    c <- chair
    b -> shaving
    c -> chair
  }
  
  action shave {
    b <- shaving
    c <- chair
    b -> shaving
    c -> leaves
  }
  
  action sleep {
    b <- shaving
    ! <- chair   # requires chair to be empty
    ! <- waiting # requires waiting to be empty
    b -> sleeping
  }
}
~~~

Note the use of !! as an input - this means that no token is consumed and that the queue
must hold entries. Likewise, a single ! does not consume a token, but requires the queue to
be empty.

Also note that the 'leave if full' action models arriving customers and gets rid of them. If
we did not remove the waiting customers we would end up with a line outside of the shop.

Barbers with specialities, and Yak's needing special trims
---
To make the problem more interesting we add multiple barbers and customers are Yaks in need of either a regular, mohawk, or poodle trim. Only some of the barbers are capable of doing a mohawk or poodle trim, no barber can perform both. All barbers can do a regular trim. There are <= number
of barbers than trimming stations.

We now have a problem of selection and optimization. We may have different margins on the different trims, have different cost for barbers with different skills, we also have a fixed cost associated with the chairs. We want to treat customers fairly.

Solution:<br/>

A barber picks first waiting yak, consults with yak regarding wanted trim. If barber
can perform the trim, or the wanted trim is a regular trim, they go off to perform the trimming,
and the waiting chair slot is freed up.

If, when consulting, the barber cannot perform the trim, the yak remains waiting with a special status, the barber then consults with the next yak.

A barber that returns from performing a trim checks if there is a matching special and
if so performs a trim and the waiting chair slot is freed up. If there is no matching special,
the barber goes back to sleeping.

~~~
type trim         = Enum[regular, mohawk, poodle]
type yak          = Struct[{ trim => Trim }]
type barber       = Struct[{can_trim => Trim}]
type consultation = Tuple[Barber, Yak, Integer]
type waiting_yak  = Tuple[Yak, Integer]

plan yakshop {
  public queue Yak arriving     { capacity => 25 } # the sidewalk outside the shop
  
  queue Waiting_yak waiting     { capacity => 5 }
  queue Waiting_yak specials    { capacity => 5 }
  queue Integer waiting_chairs  { entries => *Integer[1,5] }
  queue Consultation consulting
  queue Any    leaves           { ttl => 0 }       # self draining queue
  
  # Three barbers sleeping as we start
  queue Barber sleeping {
    entries => [
      new Barber {},
      new Barber { can_trim => 'mohawk' },
      new Barber { can_trim => 'poodle' },
    ]
  }

  action yeak_leaves_unless_there_are_free_chairs {
    y <- arriving
    ! <- waiting_chairs                            # unless there are free chairs
    y -> leaves
  }

  action a_yak_arrives {
    y     <- arriving
    c     <- waiting_chairs
    [y,c] -> waiting                               # yak y waits in chair c
  }
    
  action barber_asks_what_kind_of_trim {
    b         <- sleeping
    [y, c]    <- waiting
    !         <- wake_up_there_is_a_special_for_you # other action has higher precedence
    [b, y, c] -> consulting                         # barber is talking with yak
  }
  
  action wake_up_there_is_a_special_for_you {
    b     <- sleeping where y.trim == b.can_trim
    [y,c] <- specials
    [b,y] -> trimming
    c     -> waiting_chair
  }

  action barber_can_trim {
    [b,y,c] <- consulting where y.trim == regular || y.trim == b.can_trim
    [b,y]   -> trimming
    c       -> waiting_chairs
  }
    
  # If barber picks up yak with non matching special trim, then move yak
  # to special waiting, and barber goes back. (The yak remains waiting
  # in the same chair)
  #
  action barber_cannot_trim {
    [b,y,c] <- consulting where y.trim != regular && and y.trim != b.can_trim
    b       -> returning_barber
    [y, c]  -> specials
  }
  
  # takes a waiting pair barber/yak and a chair, gives the yak a trim, yak leaves
  # barber returns to check for more specials.
  #
  action trimming {
    [b, y, c] <- pair
    y         -> leaves
    b         -> returning_barber
    c         -> waiting_chair
  }
  
  # Barbers returning after a trim (or failed match), checks if there are
  # specials waiting
  # 
  action check_specials {
    b      <- returning_barber
    [y, c] <- specials where y.trim == b.can_trim
    [b, y] -> trimming
    c      -> waiting_chairs
  }

  action take_break {
    b  <- returning_barber
    !! <- specials where y.trim == b.can_trim
    b  -> sleeping
  }
}
~~~
  
  

