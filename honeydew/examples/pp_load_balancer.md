Load Balancer Example (puppetized)
---

The first part - ChangeRequest is a generic plan that holds on to a set of values
of type T (given when plan is instantiated),  and emits the changed set whenever it
changes.

~~~ 
type AddRemove = Enum['add', 'remove']
type ChangeRequest[T] = Struct[{'kind' => AddRemove, 'value' => T }]

plan ChangeableSet[T] {
  input  ChangeRequest[T] requests
  output Array[T]         changes
  
  public Array[T] $the_set = []
  
  action add {
    $c       <- requests where $c.kind == 'add' && ! $c.value in $the_set
    $the_set -> changes
    $the_set = $the_set + $c.value
  }
  
  action remove {
    $c       <- requests where $c.kind == 'remove' && $c.value in $the_set
    $the_set -> changes
    $the_set = $the_set - $c.value
  }
  
  # If there is a request, and neither add nor remove
  # are enabled, then the request is for an addition of something
  # already present, or a removal of something not present.
  # Such requests are simply ignored.
  #
  action drop_ignored_requests {
    $c <- requests where ! (add || remove)
    $c -> drain
  }

}
~~~

The LoadBalancer part uses the ChangeableSet to handle requests to add or remove
front ends or back ends.

> Several of the types defined in this example should be defined in a Net module - e.g.
Ip, Port, etc.

~~~

plan LoadBalancer {
  type FrontEnd {
    attr String[1]  protocol
    attr String[1]  domain
    attr Integer[1] port
  }
  type Ip = Pattern[/[0-9]{1,3}(\.[0-9]{1,3}){3}/]
  
  type BackEnd {
    attr NotUndef protocol
    attr NotUndef domain
    attr Variant[Default, Integer] port
    attr Ip host_ip
  }
  type LoadBalancerData = Variant[FrontEnd, BackEnd]
  
  input ChangeRequest[LoadBalancerData] requests
  
  $front_ends = new ChangeableSet[FrontEnd]
  $back_ends = new ChangeableSet[BackEnd]
  
  queue NotUndef[Any] change
  queue Array[Tuple[FrontEnd, BackEnd]] front_ends_by_backend_ip
  
  function matching_rows() {
   ($front_ends.the_set * $back_ends.the_set).filter | $fe, $be | {
      [$fe.protocol, $fe.domain, $fe.port] =~ [$be.protocol, $be.domain, $be.port]
   }
  }
  function group_by_ip(Array[Tuple[FrontEnd, BackEnd]] $tuples) {
    $tuples.group_by |$fe,$be| { $be.ip }
  }
  action route_fe_change {
    $r <- requests where $r.value =~ FrontEnd
    $r -> $front_ends.requests
  }
  
  action route_be_change {
    $r <- requests where $r.value =~ BackEnd
    $r -> $back_ends.requests
  }
  
  action change_in_fe {
    $c <- $front_ends.changes
    $c -> change
  }
  
  action change_in_be {
    $c <- $back_ends.changes
    $c -> change
  }
  
  action match_frontends_backends {
    $c <- change[all] after 10s
    matching_rows.group_by_ip -> front_ends_by_backend_ip
  }
  
  action update_load_balancer {
    # Not sure how this is done - producing a file with a specific format?
    # What differs between different load balancers? Derive different plans
    # Produce a File resource? If so, where? How produces?
    # How to report the change? 
    #
    $map <- front_ends_by_backend_ip
    
    # do stuff here
  }  
}

~~~

* FrontEnd and Backend could be resources
* Is the LoadBalancer a Provider for a LoadBalancer Resource? (Seems useful to be able to
  discover a physical loadbalancer's configuration.
* group_by() function is the same as the one in Ruby - we do not have that in puppet yet
