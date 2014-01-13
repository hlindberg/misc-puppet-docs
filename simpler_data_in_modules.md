Something struck me as an idea how the bindings system could be used to provide a solution similar to the params.pp one.

It is based on:

* use of regular pp logic (no yaml)
* a function bind - to bind data
* a function lookup -  to lookup data
* very simple rules (no need to configure bindings)

If we write a function called 'bind', and you use that instead of assigning a variable in the equivalence of params.pp, then people can use normal pp logic
to calculate what should be bound (like they do today).

There would be no categories etc. and layering is fixed. Just simple calls to bind.

User writes a class where the data is defined/bound.
It's name / path determines if it is autoloaded as bindings or not. (if we forget about the use case of allowing one module to configure
others, this class can be loaded on demand on init of a module).

class ntp::data {
  case $operatingsystem {
    'Gentoo': {
      bind(ntp::package_ensure, 'present')
      bind(ntp::package_name, 'net-misc/ntp')
      bind(ntp::supported, true)
      bind(ntp::servers, [
        '0.gentoo.pool.ntp.org',
        '1.gentoo.pool.ntp.org',
        '2.gentoo.pool.ntp.org',
        '3.gentoo.pool.ntp.org'
       ])
    }
  }
}

To reduce typing, the bind function takes a hash as the first argument, and a module name (prefix). Users would then write:

    case $operatingsystem {
      'Gentoo': {
        bind ({
          package_ensure => present,
          package_name   => 'net-misc/ntp',
          supported      => true,
          servers        => [ . . . ]
          },
       'ntp')
    }
  }

Data composition is as simple (or complex) as it needs to be  user can call other functions etc. as needed (In future parser users can merge hashes, iterate
etc. call bind several times looping over some structures etc.)

Then, in the classes (e.g. ntp::install) the lookup function is used:

    class ntp::install(
    $package_ensure = lookup(package::ensure, 'Boolean'), 
    $package_name   = lookup(package::name, 'String')) {

    package { 'ntp':
      ensure => $package_ensure,
      package_name => $package_name
    }

This way, users of the module can choose to use a parameterized class, or let it be instantiated using the default lookups. If they use hiera1 and databindings is on
hiera1 will win. The implementor can choose if they want to have all data for all the classes in one place, or break them up into several. They do not have to
call validate functions for simple data type checking since lookup can provide this). In the simplest configurations, they can also skip having a "params.pp" in the first
place since lookup takes a default.

The same ability to write bindings is done at the config/environment level. These bindings are loaded in a higher layer than those from modules, and are loaded
before modules are loaded. To cater for lazy loading, the config/root could allow one class per module that is loaded before that modules own (i.e. on demand loading).

Supporting different use cases of the module can be done in several ways. One way is for the module author to simply have a 'scenario' key that users of the module
set in the override. (Here I am just inventing names of things, I have not thought about this that much). (Supporting scenarios is something module authors
want (Ryan was very happy about this feature) and something the 'data in modules' provided).

e.g. user could write a class placed somewhere in relation to confdir/environment:

    class myorg::data::ntp {
      bind('somemodule::scenario', 'client-server')
    }

The module author looks this up in the class where they do bindings:

    class somemodule::data {
      if lookup('somemodule::data::scenario') == 'client-server' {
        bind ...
      }
      else {
        bind ...
      }
    }

We can have very simple, easy to learn rules:

* Data in the config dir / environment has higher precedence than data in modules
   - and is loaded before the module's data
* all of the module's data classes are auto loaded (if there are several) on init of the module
   - if data does not apply in a particular scenario etc. it is simply made conditional with pp logic.

In the future it is easy to imagine that the keyword "class" is exchanged for "data", and that the body of "data" is then restricted to not do crazy things like
adding resources to the catalog etc. Certain aspects could be formalized (like 'scenario') if we want to.

In the future lookup and typing can be done directly in the language: Say something similar to:

    class ntp::install(
      Boolean lookup $package_ensure), 
      String lookup  $package_name)) { 
        #
      }

Or simplified even further if all parameters should be looked up:

    class ntp::install lookup( Boolean $package_ensure, String $package_name)
    
It is also easy to imagine various ways to extend this; differently named files or paths loaded at different times, say contributions to included, excluded classes,
mix in with ENC etc. etc.
 
Just an idea.
