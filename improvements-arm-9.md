Improvements to ARM-9
===
September 29, 2013

Since Data in Modules (ARM-9) was introduced, it has been exposed to users trying it
out in practice. This document contains a discussion of improvements that are needed
to make it easier to use and handle additional use-cases.

Lookup
---
The following issues/comments have been raised against the current implementation:

* The expected behavior is that lookup of something that is not bound should fail.
* If failing is not wanted, a default should be given. 
* Currently the lookup function does not take an argument for default.
* It is tedious to do lookups when a first found behavior is wanted

To address these, the lookup function should be made smarter. It is not enough
to only support delegation to a lambda to do the handling of a default value. (It is still
useful for other kinds of transformations of the result, so it should not be removed)

To future-proof the function while also making it more useful it should support
the following signatures:

    lookup(String key)
    lookup(String key, String type)
    lookup(String key, PType type)                   # future, (Puppet-Type)
    lookup(String key, String type, Object default)
    lookup(String key, PType type, Object default)   # future
    lookup(String key, Hash options)                 # requires future parser to be useful
    lookup(Hash options)                             # requires future parser to be useful
    
The options hash should support:

 * type - same meaning as when given explicitly 
 * key/name - same meaning as when given explicitly; mutually exclusive with first_found
 * first_found - array of String, a list of keys to try until one is found, its value is returned
 * default - same meaning as when given explicitly
 * accept_undef - if set to true, a lookup that is undef is accepted

Examples of usage

    lookup('my_module::my_name', String, 'x')
    
    lookup { key => 'my_module::my_module_name', default => 'x' }

    lookup { first_found => ['site_params::x', 'site_params::y'], default => 'x' }

In addition to these changes, the lambda should be allowed 1-3 arguments

    |$result| { }
    |$name, $result| { }
    |$name, $result, $default| { }
    
The second and third forms are valuable when using `first_found` and/or if a default value is
used in combination with a block.

Hiera.yaml improvements
---

### Issues

#### Use named entries when structure is more complex that a list

Currently three entries are needed to specify a contribution to to a category.
Even when simplified with smart defaults, there are still cases when all of them are need.
For humans it is far easier if all elements have a name (unless the attribute is a plural).

#### Private Hierarchy

One concern that was raised was that modules often have the need to deal with operating system
and osfamily and additional machine related facts (cpu, cores, if being virtual or not) etc.

The first implementation of Hiera-2 does not handle this since all hierarchical levels
are contributed to the site-wide hierarchy. This means that the configuration at site level
needs to be modified as modules come with internal data. This breaks one of the goals; to just be
able to drop a module in.

Luckily, this is not difficult to solve since the result of using the private hierarchy can be
flattened to default bindings in the common category when contributed to the site-wide bindings.
(Remember that the contribution is specific to one request so this is safe to do).

In fact, most of what is bound in a module is probably in the common category, and the module's
`hiera.yaml` can simply consist of this:

    hiera.yaml
    ---
    version: 3
    hierarchy:
      - operatingsystem/${operatingsystem}
      - osfamily/${osfamily}

    datadir: 'data'

Which, if it is spelled out becomes this:

    hiera.yaml
    ---
    version: 3
    hierarchy:
        - category: 'common'
          paths:
             - operatingsystem/${operatingsystem}
             - osfamily/${osfamily}

    datadir: 'data'

#### The three entries have too much redundant information

Currently, the `hiera.yaml` for hiera 2 requires the hierarchy to be written like this:

    ['osfamily', '${osfamily}', 'data/osfamily/${osfamily}']
    
This is required because the three parts could be anything the user desires. 
Related is also the case for the 'common' category which requires a value of 'true' e.g.

    ['common', 'true', 'data/common']

#### Cannot specify a directory for data

Users want to be able to specify the data directory without having to repeat it in each path.

#### Operatingsystem should be included in the defaults

Since `osfamily` alone is not enough in practice, an additional category for `operatingsystem`
should be added by default.

The categories are then:

* node
* operatingsystem
* osfamily
* environment
* common


Solutions
---

### Change the structure to using objects with named attributes

#### hiera.yaml

    ---
    version: 3
    datadir:  'path to data_dir'
    hierarchy:
        - category: 'name'
          value:    '$some_var'
          paths:     
              - 'path to data'
              - 'path to data'
          datadir:  'path to datadir for this entry
        - 
          . . .

The `datadir` is relative to the hiera.yaml directory (this because a module should not be allowed to point to an arbitrary place on disk). The `datadir` defaults to `'data'`.

If a category has a `datadir` entry it is specific to the paths in that entry. 

The entry `path` accepts a single String value (a single path), and `paths` accepts an array of String (each string being a single path).


#### binder_config.yaml

    ---
    version: 2
    layers:
        -
          name: 'site'
          include: 
              - 'confdir-hiera:/'
              - 'confdir:/default?optional'  
        -
          name: 'modules'
          include:
              - 'module-hiera:/*/'
              - 'module:/*::default'
          exclude:
              - 'module-hiera:/bad_boy/*'
    
    categories:
        -
           name: 'node'
           value: '${fqdn}'
        -
           name: 'operatingsystem'
           value: '${operatingsystem}'
        -
           name: 'osfamily'
           value: '${osfamily}'
        -
           name: 'environment'
           value: '${environment}'
        -
           name: 'common'
           value: true


#### Use smart defaults

If only the category name is given make the following assumptions:

* the value is the value of a variable with the same name as the category (unless it is
  `common` which is always 'true')
* the path is `'category/value'`
* `datadir` defaults to 'data'
* if a string is given instead of an object, it is the category name

i.e. which makes it enough to specify:

    ---
    version: 3
    hierarchy:
        - category: 'environment'
        - category: 'operatingsystem'
        - category: 'osfamily'
        - category: 'common'
        
Since the rest can be derived.

Similar rules can be applied to `binder_config.yaml` to make the default look like this:

    ---
    version: 2
    layers:
        -
          name: 'site'
          include: 
              - 'confdir-hiera:/'
              - 'confdir:/default?optional'  
        -
          name: 'modules'
          include:
              - 'module-hiera:/*/'
              - 'module:/*::default'
          exclude:
              - 'module-hiera:/bad_boy/*'
    
    categories:
        - ['node', '${fqdn}']
        - 'operatingsystem'
        - 'osfamily'
        - 'environment'
        - 'common'
        
    extensions:
      hiera-backends:
        my_yaml: 'Puppetx::MyModule::MyYaml
        my_json: 'Puppetx::MyModule::MyJson

      scheme-handlers:
        myservice: 'Puppetx::MyModule::MyService

Note that category node can not use defaults at the moment since it is not decided which
variable should be the default node selection variable. *OUTSTANDING ISSUE*.

### Support multiple paths per category

This effectively hides the decisions made and flattens the contribution to the given
category. If an equally elaborate structure is wanted at the site level to handle overrides
it is the decision that is independent of how it is structured in the module.

As an example, the ntp module may contribute

    when common {
      bind 'ntp::package_name' to 'misc-net/ntp'
    }

Even if its decision to contribute this name is based on osfamily and operatingsystem.
