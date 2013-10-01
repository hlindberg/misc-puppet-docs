Structured Bindings for Data in  Modules
===

A common complaint about using hiera data is that it quickly gets very complex to maintain:

* Values that related to a particular concern are spread out over several files
* Peephole feeling when looking at data files
* Loosing track of what is where in a sea of small yaml snippets
* Need to use tricks in the hiera.yaml to scan files more than once
* Using combinations of variables

These are inherent problems in a search-path based approach.

In ARM-8 the idea is expressed that users should write data bindings in the puppet language.
This would make the data aspect a first order thing in the language and it would help users that struggle with yaml syntax. This will however take some time to implement.

There is however a much quicker solution that can be implemented. The Puppet Bindings system is really not tied to one particular data representation, and using a richer yaml format than Hiera-2 would make it possible to expose more features from the underlying Puppet Bindings system.

Basically, the idea is to represent the support for bindings in Ruby in Yaml.

i.e. given these Ruby bindings:

    Puppet::Bindings.newbindings('mymodule::default') do
      bind {
        name 'has_funny_hat'
        to 'the_pope'
      }
      
      when_in_category('osfamily', 'darwin') {
        bind {
          name 'has_funny_hat'
          to 'steve martin'
        }
      }
      
      when_in_category('environment', 'production') {
        bind {
          name 'has_funny_hat'
          to 'comedians'
        }
      }
    end
    
This can be expressed in yaml

    ---
    bindings_version: 1
    name: 'ntp::default'
    bind:
      - ['has_funny_hat', 'the_pope']

      - when:
          osfamily: 'darwin'
        bind: 
          - ['has_funny_hat', 'steve_martin']

      - when:
          environment: 'production'
        bind:
          - ['has_funny_hat', 'comedians']
        
The format can support the above 'short form', but also a spelled out 'long form'

    ---
    bindings_version: 1
    name: 'ntp::default'
    bind:
      - name: 'has_funny_hat'
        to: 'the_pope'

      - when:
          osfamily: 'darwin'
        bind:
          - name: 'has_funny_hat'
            to: 'steve_martin'
          
      - when:
          environment: 'production'
        bind: 
          - name: 'has_funny_hat'
            to:   'comedians'

The long form makes it possible to support more features from Puppet Bindings, i.e. features not available using Hiera-2 data.

Top Level
---
The top level has the following attributes:

* **bindings_version**: - tells the system this is bindings, and which version
* **name**: - the logical name of the bindings
* **bind**: - what to bind, see below

Bind
---
Bind is what defines one or several bindings

the attribute bind is always an array. The entries are one of:

* **array** - two slot array [name, value], this is the short form
* **hash**  - a Binding Hash, or a Conditional Bindings Hash

Binding Hash
---
The Bindings Hash has the following attributes:

Regular binding:

* **name**: the name to bind 
* **type**: the type of the bind (is inferred if not stated)
* **to**:   the value to bind, strings are interpolated

Support for Multibinding:

* **multibind_id**: the id other bindings can contribute to
* **in**:   reference to a multibind id by name, adds the data to the mutibind
* **options**: hash, content depends on producer
  * For a hash multibind:
    * **conflict_resolution**: one of error, merge, append, priority, ignore
    * **flatten**: true, or integer (level)
    * **uniq**: boolean - boolean, if appended results should be made unique
  * For an array Multibind:
    * **flatten**: boolean or integer
    * **priority_on_named**: boolean (true by default, highest priority element with name collected)
    * **priority_on_unnamed**: boolean (false by default, all are collected).
    * **uniq**: boolean, make array result contain unique elements only

Other lookups:

* **to_first_found**: - array of names
* **to_lookup_of**: - lookup of another key
* **to_hash_lookup**: Hash, containing name: the name to lookup, and key: the key to lookup in found hash

To expression - the string is taken as source text, not a puppet string:

* to_expression: a puppet expression in string form (may use interpolation and other expression)

Binding Kind (helps with system maintenance):

* **abstract**: - boolean, forces someone else to provide the binding
* **override**: - boolean, this binding must override something, or it is an error in the config

More advanced features supported by Puppet Bindings - **questionable to expose these in this format**:

* **to_instance**: - name of a ruby class, or array with [classname, arg1, arg2]
* **to_producer**: - producer object
  * **class_name**: the name of a ruby class that is instantiated to produce the value 


Conditional Bindings
---
A Conditional Bindings makes the bindings conditional on one or several categories.
It also supports nested conditional bindings.

The attributes are:

* **when**: hash of category to value map, the request must be in all the given categories, and has
  elevated precedence based on the categories precedence (priority between highest and it's next 
  higher priority). (multiple categories is the same as nesting one when inside another, and the 
  listing all the bindings).
* **bind**: - what to bind, same as for top bindings (Binding Hash, Conditional Bindings Hash)

  
  Example:
      
      when:
          node: 'kermit.example.com'
          environment: 'production'
      bind:
          - 

This means when node is kermit.example.com, and in production the made bindings have higher precedence than anything bound for just kermit, or just production. (In Hiera this requires inventing a combined level).

File location
===
ARM-9 suggests placing these under a directory called bindings, and that the name of the file must reflect the name of the bindings. Thus a module called 'awesome' with a 'default' set would have
the following layout:

    <module>
    |-- bindings                   #  Where all the data is kept
    |   |-- default.yaml            #  Module's common bindings

And the yaml contains:

    ---
    bindings_version: 1
    name: 'awesome::default'

If awesome had bindings named `awesome::for_x::default`, it would be placed in `./bindings/for_x/default.yaml.`
    
Inclusion
---
The confdir: and module: schemes are modified to also look under ./bindings. (If found both under ruby and ./bindings, it is an error). 

Later, if ARM-9 .pp concrete syntax for the same thing is also implemented, users can use either .yaml or .pp files.

 