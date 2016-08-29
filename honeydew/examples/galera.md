Galera Cluster Example
---
Galera is a cluster for MySQL/MariaDB. The cluster is "multi-master". The problems with
bringing a cluster up, and dynamically manage it are:

* If quorum is not possible the cluster refuses to start
* When bringing up the cluster, a special "open" mode needs to be used (the first node is otherwise not enough to form a fail-safe quorum).
* If nodes go down/become unavailable because of split-brain, to the point where quorum cannot be reached, the entire cluster goes down and needs to be handled manually (recovery).

## Catalogs


### Cluster Member Nodes

In the catalog for a node that is going to be part of a cluster. In this example 'cluster_1'

~~~
  galera::host { 'cluster_member':
    cluster => 'cluster_1',
    host    => $trusted[certname],
  }
  -> package { galera: ... }
  -> db_snapshot_install { ...: ... }       # import snapshot db
  -> service { 'galera':                    # begin with service stopped
       ensure => stopped,
  }
  -> event { 'install_complete' :
       to   => Galera::Host['cluster_member'],
       fire => immediately,
     }
  -> event {
       service_refreshed :
         to   => Galera::Host['cluster_member'],
         fire => on_notify,
     }
~~~

At this point, the following has occurred:

* galera::host plan is running from the start of the catalog
* all resources in the catalog are applied, meaning that:
  * everything required is installed
  * the database is initialized from a snapshot
  * galera service is in stopped state
* orchestrator knows about the plan
* plan is informed when the installation is complete

### Orchestrator

In the Orchestrator

~~~
  galera::cluster { 'cluster_1' :
    cluster_size => 5
  }
~~~


## Definitions of plans

TODO:

  * event queue, and type constraints
  * 
  
~~~
plan galera::leader inherits galera::host {

  # Leader's role is 0, followers' are 1 to cluster size
  # (This overrides the $galera::host::desired_role variable)
  #
  $desired_role = 0
  
  # Leader has these externally observable states
  #
  output state leader_not_running, leader_running

  # This notifies the orchestrator that the leader's service
  # is running. Followers can now join the cluster.
  #
  action when_leader_galera_service_is_running {
    $e             <- events where e.message == 'service_running'
    leader_running -> state
  }  
}


plan galera::follower inherits galera::host {

  input state
    leader_not_accepting_members,
    leader_accepting_any_member,
    accepting_known_members
  
  function galera_service() {
    Service.new {
      title  => 'galera::service',
      ensure => started,
      notify => Event[service_refreshed]
    }
  }

  action when_install_is_completed {
    $e <- events where $e.message = 'install_complete'
    
  }
  
  function leader_map_resource(Hash[Integer, Ip] $map) {
    File.new {
      title   => $config_file,
      content => "members = ${$map[0]}",
    }
  }

  action post_catalog {
    # waiting for the catalog to be done syncing
    # i.e. all packages, users, db initialization
    # - no config yet
    # - service not started as leader running is required
    # - all members may not be known, start with at least leader
    #
    _                       <- main::catalog_done
    _                       <- state server_running
    leader_map_resource()   -> resources_to_sync
    galera_service()        -> resources_to_sync
  }
  
  # inherited action refreshes service when all members are known

}

plan galera::host {
  # Assigned when plan is instantiated i.e.
  #
  public String $host
  
  String $config_file = '/etc/galera/config'
  
  # Casted role is the role the cluster gave this host - a tuple of [role, cluster_size]
  input Tuple[Integer, Integer] casted_role { latched => true }
  
  # Cluster size is known by the cluster, and this plan is given this value
  # by the cluster.
  #
  input Integer cluster_size
  
  # As the cluster changes members, a new member map is produced by the cluster
  # and it is is received here.
  #
  input Hash[Integer, String] member_map
  
  # Remembered current values
  #
  Optional[Integer]           $the_cluster_size
  Optional[Integer]           $the_role
  Optional[Hash[Integer, Ip]] $the_member_map
  
  action initialize {
    orchestrate(self)        # orchestrator hands off to GaleraCluster, send info back
  }

  action join_cluster {
    [$role, $size]    <- casted_role where $the_role == undef
    $the_cluster_size = $size
    $the_role         = $role
  }

  function map_resource(Hash[Integer, Ip] $map) {
    File.new {
      title   => $config_file,
      content => "members = ${($map - $role).values}",
      notify  => Service[galera],
    }
  }
  
  action when_all_have_joined {
    $map           <- member_map where $map.size == $cluster_size
    map_resource() -> resources_to_sync
    # remember the last map
    $the_map       = $map
  }

  action when_some_have_joined {
    $map <- member_map where $map_size != $cluster_size
    # TODO: possible actions other than just remembering and waiting ?
    $the_map = $map
  }

  function is_leader() {
    $role == 0
  }
  
  function is_follower() {
    $role > 0
  }
  
  action a_follower_knows_its_leader {
    $map <- member_map where $map[0] != undef && is_follower()
    # Leader may not be ready, but config can be produced to be ready
    # to join leader when it is up.
  }
  
  action changing_cluster_size {
    $size <- cluster_size where $known_cluster_size =~ Integer
    # TODO: Fail, cannot change cluster size?
  }

  action changing_role {
    $role <- cluster_size where $my_role =~ Integer
    # TODO: Fail, cannot change role in cluster?
  }
  
}

 # The galera::cluster is an orchestrator that is parameterized with
 # the type of plan it can orchestrate.
 # This provides the cluster plan with an input queue called 'requests'
 # where orchestrated Galera::Host plans can be added and removed.
 # 
plan galera::cluster inherits orchestrator[Galera::Host] {

  # Default number of followers, can be overridden when instantiating the plan
  # e.g. GaleraCluster.new { cluster_size => 5}
  #
  public $cluster_size = 3
  $role_range = Integer[1, $cluster_size]
  
  # Leader(s) and Followers are added or removed using change requests
  #
  public input ChangeRequest[GaleraClusterHost] requests
    
  # A queue populated with integers 0 (leader) to given capacity
  queue Integer available_slots { entries => *$role_range }
  queue Hash[$role_range, Galera::Host] casted_hosts
  queue Hash[$role_range, Galera::Host] clustered_hosts
  
  queue Boolean hosts_need_new_map

  action assign_role {
    [$kind, $value]        <- requests where $kind == 'add'
    $role                  <- available_roles     # picks 1,2,3.. etc
    [$role, $cluster_size] -> $value.casted_role  # tell host role and cluster size
    {$role => $value}      -> casted_roles        # continue processing in parallel
  }

  action handle_cluster_change {
    $casted                        <- casted_hosts
    $clustered                     <- clustered_hosts
    $clustered + $casted           -> clustered_hosts    
    role_map($clustered + $casted) -> hosts_need_new_map
  }
  
  # Produces hash of role => ip
  function role_map(Hash[Integer, Galera::Host] $hosts) {
    {} + $hosts.map |$key, $value| { [$key, $value.host] }
  }
  
  # Sends the last produced map to all known hosts in cluster
  # (meaningless to send intermediate states in this cluster)
  #
  action send_last_member_map_to_all {
    $hostmaps        <- hosts_need_new_map[all]
    $clustered_hosts <-> clustered_hosts
    $hostmaps[-1] -> * $clustered_hosts.map |_, $host| { $host.member_map }
  }
  
}
~~~

Notes:

1. Since it is meaningless to have a unit value, the notation $ is used for this
2. the next_state() function advances state in given order. When reaching the end state it
  does not change further. Since in this case, state is one dimensional there is no need to
  identify the state.
3. No information is needed when adva