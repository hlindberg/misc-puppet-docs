Client Server Example
---

~~~
type db_info = Struct[{db_name => String, db_host => String}]

class three_tier_application($db_name) {

  plan db_server_plan(String db_name, String host) {
    output Db_info db_info
    action produce_information {
      new Db_info { 
        db_name => db_name,
        db_host => host
      } -> db_info
    }
  }

  class db_installation {
    # packages and other resources that makes it possible to create a named
    # db
  }

  class db_client_installation {
    # packages etc. needed on the client
  }

  define db($db_name, $db_schema) {
    # run the plan
    three_tier_application::db_server_plan { $title: 
      db_name => $db_name: 
      schema  => $db_schema
    }
  }
  
  plan db_client {
    input Db_info db_info
  }
}

node the_db_server {
  # install db
  include three_tier_application::db_installation
  
  # create a database
  db {'cars_db':
    db_name   => 'my_cars',
    db_schema => "create table car(regnbr varchar(20))"
  }
  Class[db_installation] -> Db['my_cars']
}

node a_db_client {
  include three_tier_application::db_client
  define db_client(String $db_name, String $db_host) {
    # whatever we need here
  }
  
  db_client{ 'the_client':
    # since names match
    * => $three_tier_application::db_client::db_info
  }
 
}
~~~



A Catalog
---

The catalog:
~~~
notify { 'a': }
notify { 'a2':}
notify { 'b': }
notify { 'c': }
Notify[a] -> Notify[b]
Notify[a2]-> Notify[b]
Notify[b] -> Notify[c]
~~~
Can be expressed as the honeydew program:
~~~
plan catalog inherits resource_catalog {
  resources {
    notify { 'a': }
    notify { 'a2':}
    notify { 'b': }
    notify { 'c': }
  }
  action a {
    a <- Notify[a]
    a -> Notify[b]
    a -> sync
  }
  action a2 {
    a2 <- Notify[a2]
    a2 -> Notify[b]
    a2 -> sync
  }
}

plan standard_resource {
  queue  Resource     desired_state
  output Resource     actual_state
  output ResourceDiff resource_diff
  output Resource     end_state
  Provider p
  
  function provider(Resource r) {
    
  }

  action apply {
    r         <- desired_state
    p         <- provider(r)
    p.actual  -> actual
    p.diff    -> diff
    p.applied -> applied
  }
  
  action apply {
    ! <- catalog::noop_mode
      
}
  
plan notify::a inherits standard_resource { 
  the_resource = new Notify { title => 'a' }
  queue desired { entries => the_resource}
}
// resource a2 is the same
plan notify::b inherits standard_resource {

  action apply  {
    !! <- notify::a.applied
    !! <- notify::a2.applied
  }
}

=====

plan top_resource {
  Resource r
  Provider p
  
  action apply provider {
    p.generate(r)
    r.
  }
}

plan notify_a {
  r = Resource.new { type => Notify, title = 'a'}
  p = provider(r)

  
plan resource_catalog {
  input Resource ready
  input Provider ready_to_run
  
  action resolve_provider {
    r <- ready
    [r, provider(r)] -> ready_to_run
  }
  
  action run_provider
    [r, provider] <- ready_to_run
    
  
    
    
    