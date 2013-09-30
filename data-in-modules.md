Data in Modules
===============
In Puppet version 3.3 there is a new experimental feature for handling *data in modules* using an updated version of Hiera referred to as Hiera-2. The primary goal of the new feature is to enable module authors to supply *users* (i.e. those that later use the module) with default values that
take effect with as little work as possible by the user while also allowing override and customization of the overall system's configuration.

Before looking at how the new feature works lets take a look at the options for handling data in modules before this feature and what the problems look like in practice.

The Basic Problem with "Data"
-----------------------------
In this section we are using a module for handling ntp as an example how to handle data. 
Note that these examples are kept short, only showing support for a very small selection of the real concerns / parameters involved when writing a real ntp module - this to show the principles of handling data, not how to write an ntp module.

### Hardcoding Data

Clearly, the simplest (and least flexible) way of handling data is to hardcode it directly in a manifest at the point where it is used. Let's look at a relatively simple thing as NTP as an example.


    class ntp {
      package { 'ntp':
        ensure => present
      }
    }

The problems starts immediately if we want this to work across all platforms since
the package name is not the same on every operating system.
For most it is `'ntp'`, but on FreeBSD it is `'net/ntp'`, and for Gentoo it is `'net-misc/ntp'`.

Again we can hardcode that decision (as in this warning example what not to do).

    class ntp {
      package { 'ntp':
        ensure => present
        name   => $::osfamily ? {
          'FreeBSD' => 'net/ntp',
          'Linux'   => $::operatingsystem ? {
              'Gentoo' => 'net-misc/ntp'
              default  => error('unsupported')
            },
          default   => 'ntp'
        }
    }

This already looks ugly, as the important piece of the logic is dwarfed by the decisions about parameter value selection. And we have just started! A real ntp module would have a dozen parameters for the service and its configuration. 

The obvious problems with this approach are:

* For someone else to use this class/module and set some other value they have to make a copy of it
  and change it locally. We call this the *'clone and own'*-antipattern.
* The logic is hard to read
* The concern of "which values apply per platform" is spread out across the manifest
  since decisions are made per parameter (thus you cannot
  easily find all the parameters for one platform in one place).
* It is hard to see if each platform is completely handled.

It becomes slightly better if the decisions are broken out into variables. But they are still hardcoded.

    class ntp {
      $package_name = $::osfamily ? {
          'FreeBSD' => 'net/ntp',
          'Linux'   => $::operatingsystem ? {
              'Gentoo' => 'net-misc/ntp'
              default  => error('unsupported')
            },
          default   => 'ntp'
        }
    
      package { 'ntp':
        ensure => present
        name   => $package_name
      }
    }

We can make some of the mentioned problems go away by reorganizing the logic:

    class ntp {
      case $::osfamily {

        'FreeBSD' : {
          $package_name = 'net/ntp'
        }

        'Linux' : {
          unless $::operatingsystem == 'Gentoo' { error "Not supported") }
          $package_name = 'net-misc/ntp'
        }
        
        default : {
          $package_name = 'ntp'
        }
      }
      
      package { 'ntp':
        ensure => present
        name   => $package_name
      }
    }

It is now much clearer to see what is being set per platform. The data is still hard coded though.

### Parameterizing the class

Since we want the user of our module to be able to override any of the parameters we could make
use of a parameterized class.

We immediately run into trouble:

    class ntp($package_name = <WHAT?>) {
      . . .
    }
    
How do we specify the default value here? Should we place the messy selector expression here?
What about the 12 other parameters? That would be the parameter declaration from hell and we just moved the complexity to a different location.

At this point, you may be tempted to declare the default as an empty string, and then test
if something was given.

    class ntp($package_name = '') {
      if $package_name == '' {
        $effective_package_name = <THE SELECTOR FROM BEFORE>
      else
        $effective_package_name = $package_name
      }
      
      package { 'ntp':
        ensure => present
        name   = $effectice_package_name
      }
   }
  
The problems now are: 

* We must either have each parameter use a selector (selecting the given parameter
  e.g. `$package_name`, or the the selection logic for that parameter), or use an extra variable
  (the `$effective_package_name` in the example above). As you already seen, nesting the logic
  per parameter has very low readability. The extra variable is a lesser evil in this case.
* We now have a *leaking variables*-antipattern, you must make sure you use a unique name
  and if you need other logic to refer to the result (as oppose to the given value) this logic
  would have to use the internally named variable (i.e. `$effective_package_nam`e in the example).
  This is confusing (it is set as `'package_name'` from the user's perspective, but who knows on 
  the outside if this value is mangled in any way before it is used).
* How can a user even figure out that they should refer to `$effective_package_name`?

### The params.pp pattern

A pattern used by many modules is to create a `params` class for the module where all the parameters
of the modules are centralized. This class is not parameterized.

    class ntp::params {
      case $::osfamily

        'FreeBSD' : {
          $package_name = 'net/ntp'
        }

        'Linux' : {
          unless $::operatingsystem == 'Gentoo' { error "Not supported") }
          $package_name = 'net-misc/ntp'
        }
        
        default : {
          $package_name = 'ntp'
        }
    }
    
We can now easily make use of these parameters in out `ntp` class (as well as the other classes in our module where we need parameters) by inheriting the `ntp::params` class.

    class ntp inherits ntp::params {
      package { 'ntp':
        ensure => present
        name   => $package_name
      }
    }

We are now back to sanity in our `ntp` class. As the *data-concern* has moved elsewhere we can again focus on the logic of the class itself.

What is wrong now? This looks pretty good:

* At this point our `ntp::params` is still hardcoded and we are yet again subject to the
  *'clone-and-own'*-antipattern!

We cannot solve this by parameterizing the ntp class (to either use a given value or the inherited variables), and if we parameterize the `ntp::params` class the users would have to supply the parameters to that instead, and we we just recreated the original problem - but in a different place!

This is where the use of Hiera comes into play.

### Using Hiera-1 to handle the data

We now need to do two things, wire Hiera into our class, and supply the data. We will start by doing this using Hiera-1 (and later show how 'data-in-modules' and Hiera-2 is used).

In our example, we really do not need the `ntp::params`, but in practice there may be some parameters
that are hardcoded; like 'factory settings' or things that should really *be* hard coded, but maintained in a centralized place. We will skip this for the sake of brevity.

So, back again to our `ntp` class. It is again parameterized, and we provide the default `'ntp'` (since this is what the package name is on most platforms).

    class ntp ($package_name = 'ntp') {
      package { 'ntp':
        ensure => present
        name   => $package_name
      }
    }

If we stop there we pushed the problem over to the user to set the correct package name per platform. How can we give the user the data/configuration to use? Well, in Hiera-1 there is no way to do this
except by providing a sample that the user needs to wire into their overall Hiera-1 hierarchy. This must then be pointed out in documentation. If the user does not see this, the result is a failure
on platforms that required a different package name. This is not very nice.

You could add something like this to your module:

    <module>
    |-- data                       #  Where all the data is kept
    |   |-- common.yaml            #  Module's common bindings
    |   |-- osfamily               #  Data per osfamily
    |   |   |-- FreeBSD.yaml       #  Data for FreeBSD
    |   |   |-- . . .              #  etc.
    |   |-- operatingsystem        #  Data per operatingsystem
    |   |   |-- Gentoo.yaml        #  Data for Gentoo

The problem now for the consumer is to integrate that into the overall Hiera-1 hierarchy. The data must be copied over and placed with the rest of the site-wide data. As an alternative, the specifics for the ntp module could be placed as a set of hierarchy levels in the configuration and not mixed in with other settings. But integration is in any case needed and it is hard to provide easy to copy/paste data because the configuration it is going to be pasted into is completely up to the user.

An obvious integration problem is that other modules also may have settings that differ per osfamily and operatingsystem.

Lets look at what this problem looks like in practice.

The hiera-1 hiera.yaml specifies a hierarchy. And if you are already using hiera, you may have something like this:

    ---
    :hierachy:
      - node/%{::fqdn}
      - environment/%{::environment}
      - common

The user now needs to add the two additional hierarchy levels, and decide where they fit into the
overall hierarchy.

    ---
    :hierachy:
      - node/%{::fqdn}
      - environment/%{::environment}
      - operatingsystem/%{::operatingsystem}
      - osfamily/%{::osfamily}
      - common

At this point the problems are:

* If two modules that are being integrated uses conflicting relative hierarchy levels, these must be 
  separated by inventing new levels and then placing the different modules entries in an artificial 
  order (i.e. the actual order between the modules' entries does not matter).
* If all modules have osfamily and operatingsystem in the same order, we still need to keep all the 
  FreeBSD data in the same file - unless, we also for this problem break out the hierarchies
  into a separate set.
  
Let's look at what the solution looks like (for both cases). We invent the module `romulan` (Romulans are not known for the adherence to logic) that has `osfamily` and `operatingsystem` reversed. We could then do this.

    ---
    :hierachy:
      - node/%{::fqdn}
      - environment/%{::environment}
      - ntp/operatingsystem/%{::operatingsystem}
      - ntp/osfamily/%{::osfamily}
      - romulan/osfamily/%{::osfamily}
      - romulan/operatingsystem/%{::operatingsystem}
      - common

What are the problems at this point:

* We may have hundreds of modules (some written by "Romulan" users), and we end up with
  a long list and lots of searching for data.
* This is however a lesser evil than copying the romulan module settings and the ntp settings into 
  the same file (e.g. `operatingsystem/FreeBSD.yaml`). This is particularly bad if someone later
  decides that the data in the `FreeBSD.yaml` file can be refactored/optimized by intermingling
  the logic from the two modules. After that it is close to impossible to remove one of the modules.
* We have manual work to do for each update of each module that has data. (And the smarter people
  got we the data as described in the previous bullet, the worse it gets).
* Basically we now have a *clone-and-own*-antipattern for the *data-concern*. It is better than what 
  we started with, but it is still quite bad.
  
#### Wiring the data

The wiring of the data is simple as we get automatic lookup of parameters. If they are not defined in data, the parameter's default will be used. We just have to use the correct fully qualified names in our data bindings.

**data/FreeBSD.yaml**
  
    ---
    ntp::package_name: 'net/ntp'

We must ensure that we got the data type we expected in the ntp class. We can do this with
one of the `validate_xxx` functions in the standard library:

    class ntp($package_name) {
      validate_string($package_name)
    }

If you feel that the automatic coupling of data to parameter is too magic and you want to be explicit
we can use the lookup functions (called `hiera` in Hiera-1).

    class ntp($package_name = hiera('ntp::package_name')) {
      . . . 
    }

Can you spot the problem with this approach? The answer is that if the data bindings contains a set value for `ntp::package_name` it will win. If it is not set, then it is not meaningful to look it up. We can turn off automatic data binding completely, but that may be bad for other use cases. So what to do? We could use different names than the obvious ones, but that just created us two new problems (we have to have these fictitious names, and they could still be defined in the data - so we are actually worse off!).

Instead we are back at not using a parameterized class, and instead use `ntp::params`, only now
letting it look up the values. That looks like this:

    class ntp::params {
      $package_name = hiera('ntp::package_name')
    )
    class ntp inherits ntp::params {
      package { 'ntp':
        ensure => present
        name   => $package_name
      }
    }

The choice we are making is between implicit and explicit parameter data binding, and whether the
user should be able to override the values using data-bindings only, or in either data or
their logic. If we lookup the parameters inside the class and assign them to variables the user can only vary the behavior by changing the data. If we use the implicit data binding, it is meaningless to use the `hiera` function to explicitly lookup data since it would only be used if the data was not available in the first place.

At this point we are down to a matter of taste; and there are two schools - those who like parameterized classes for the job and those that do not. The opinions are further subdivided between
those that prefer explicit lookup over implicit as the former makes it easier to understand where
data is coming from, while the second is believed to be clearer.

<table>
<tr>
<th>implicit</th><th>explicit</th>
</tr>
<tr>
<td><pre>
class ntp($package_name) {
  validate_string($package_name)
  package {'ntp':
    ensure =&gt; present
    name   =&gt; $package_name
  }
}
</pre></td>
<td><pre>
class ntp::params {
  $package_name = hiera('ntp::package_name')
  validate_string($package_name)
}
class ntp inherits ntp::params {
  package {'ntp':
    ensure =&gt; present
    name   =&gt; $package_name
  }
}
</pre></td>
</tr>
<tr>
<td>
  <ul>
    <li>each class responsible for its own parameters</li>
    <li>each class validates them</li>
    <li>uses parameterized classes</li>
    <li>requires more extensive refactoring from existing params.pp</li>
    <li>can not see where data comes from</li>
  </ul>
</td>
<td>
  <ul>
    <li>centralizes parameters in the module</li>
    <li>easier to document all parameters for the module in one place</li>
    <li>less in each class</li>
    <li>does not use parameterized classes</li>
    <li>easy to convert to from hard coded params.pp</li>    
    <li>can see where data comes from</li>
  </ul>
</td>
</tr>
</table>

### Summary

As you could see in this progression from hard-coded data to implicitly bound parameters using
Hiera-1 as the mechanism there is simply not just the distinction of "code" vs. "data" - we are actually dealing with multiple concerns that we like to keep separate:

* The code should be easy to read and understand
* We need to compose data from several sources (the site level configuration, and modules)
* We want modules to be easily dropped into a site/environment configuration
   * we do not want to be required to manually edit files at the site/environment
     level as we add/remove modules
   * we may have dynamic environments which are pretty much impossible to support if constant
     change is required at the site/environment level.
* Modules should not step on each other

What we have just seen is:

* Use of Hiera-1 makes a clean separation of data and code
* The centralized nature of Hiera-1 gives us new issues we end up with a plethora of hierarchical
  levels and flea market of small data files since we need to support the requirements
  of every module in one place.
* We must manually maintain this structure as modules change.
* We must manually maintain this structure as we add or remove modules

Possible work arounds for some of the problems, but none of them are very appealing:

* We could point directly to the data in modules (and not having to copy the data), this makes
  it easier to get updates but requires that modules are always located at the same relative
  position.
* We could symlink the data to the central location

There are also technical issues:

* Hiera-1 is static in nature as it reads the configuration when the master starts. Adding or
  removing levels in the hierarchy requires a restart.
  
Data in Modules
===============
The experimental support for "data in modules" in Puppet 3.3.0 is a first implementation of facilities intended to solve the data composition issues. A full description and technical detail is 
found in [ARM-9 Data-in-modules](http://links.puppetlabs.com/arm9-data_in_modules); a document you may want to read when digging deeper into the technical possibilities - but it is not required reading to begin using Data-in-modules and Hiera-2.

You can safely skip reading the armature text at this point. The questions about what armatures is, the relationship between ARM-9 and ARM-8 (the ideas ARM-9 is based on), and the rationale for the implementation, are answered in the [FAQ](#FAQ) at the end of this document.

Please note that the first implementation is experimental - the purpose is to get early feedback.

**News !**

A number of issues have already been raised and solutions have been implemented.
This document describes the support that is added in the branch [arm9-puppet-3_4](https://github.com/hlindberg/puppet/tree/feature/arm9-puppet-3_4), and a brief description is made of how the corresponding features work when used with what is already in Puppet 3.3.0.

The branch combines implementation of the Puppet Redmine issues #22574, #22646, and #22593.

### Main Features

In short, Data in Modules does the following:

* It allows you to directly use the data inside of the module. The data does not have to be
  copied and maintained in a central location.
* The inclusion (and exclusion) are controlled by patterns so you do not have to change the
  configuration as modules are added or removed (unless there is something wrong or special you
  need to patch).
* You are given control over how the data from modules is composed and arranged in relation to
  other sources e.g. site level data overrides module level data.
* Data bindings can be expressed in Hiera-2, or in Ruby.
* A module (and the site/environment) may have multiple sets of data to allow a configuration
  to select the suitable data sets. This can be used for several purposes; allowing modules to
  supply defaults for different common configuration types, allow a module to be created for the sole 
  purpose of contributing different kinds of configuration for a combination of modules (i.e. a kind 
  of higher order module like a "lamp-stack" which in itself does not contain much functionality but 
  it may configure the modules it depends on).
  
Added in the proposed changes for Puppet 3.4:

* A module may use a "private" hierarchy, other modules does not have to use the same hierarchy.
  (This is the default).
* A module may contribute data that is "woven" into an overall hierarchy. (This was the only mode
  in the Puppet 3.3 implementation).

#### Category
  
The term "category" is used in data-in-modules to denote a *"named level in the overall hierarchy"*. So when you read *"the common category"*, this means the *"The 'common' hierarchal level/priority in the site-wide overall hierarchy"*. In Hiera-1, there is no corresponding term, it simply has a lists of paths. It may help to mentally translate the expression *"the osfamily category"* to a Hiera-1 path such as `"osfamily/${osfamily}"` - i.e. *"the data that is specific to osfamily"*. 

The category concept is explained further when explaining how the site-wide composition of all data is done.

### Hiera-2 Features

The major differences between Hiera-1 and Hiera-2 are:

* Hiera-2 uses Puppet Language syntax for interpolation of expressions - i.e. `${expression}`, where
  Hiera-1 only supported interpolation of variables, and with a different syntax `%{varname}`.
* The `hiera.yaml` configuration file has changed
    * variables are interpolated using Puppet Language syntax
    * when the result is to be woven into the the overall hierarchy of data, there is the need
      to specify how.
* Hiera-2 loads dynamically, if the `hiera.yaml` is changed these changes are picked up
  when processing the next request (e.g. for a catalog).

Introducing data-in-modules presented an opportunity to also address general issues. Hiera-1 only allows interpolate of variables and uses a different interpolation syntax (`%{varname}`) than the Puppet Language (`${expression}`).

In Hiera-2 any Puppet expression that is normally allowed in interpolation, can be used, including 
function calls. A string in Hiera-2 data, is treated like a Puppet Language double quoted string, which means that it supports interpolation and escaping of special characters.

The other notable changes to the `hiera.yaml` are those that deal with weaving the module's data with data from other modules.

Note that it is still possible to use Hiera-1, and even combine it with Hiera-2. Hiera-2 may be used both at site level and for contributions from modules.

Wiring Data in the Module
---
In this step we are going to configure the module to use Hiera-2. Here is what we
need to do:

* Add the data structure to the module (just like earlier shown for Hiera-1)
* If the data already exists in the form of Hiera-1 data, we must modify the interpolation and
  ensure special characters are escaped.
* Tell the Puppet Bindings system how this data is organized
* Make use of the data in our module's logic

The following sections describe these steps.

### Add the data structure to the module

You need the data in the module. The default settings are to use a directory called `data` under the module's root directory. We will use that. (This is the same structure as shown earlier for Hiera-1).

    <module>
    |-- data                       #  Where all the data is kept
    |   |-- common.yaml            #  Module's common bindings
    |   |-- osfamily               #  Data per osfamily
    |   |   |-- FreeBSD.yaml       #  Data for FreeBSD
    |   |   |-- . . .              #  etc.
    |   |-- operatingsystem        #  Data per operatingsystem
    |   |   |-- Gentoo.yaml        #  Data for Gentoo


### Interpolation and Escaping Special Characters

And since we did not use any interpolation in the data in our earlier example, there is nothing to change. If there was, we would need to change the `%{varname}` Hiera-1 syntax to `${varname}`
(or `$varname`). We also need to look at the use of a literal `$` since it needs to be escaped. While doing this, attention is also needed to the backslash `\` character as it is now used for escaping. In short - Hiera-2 uses the same rules as for the Puppet Language double quoted string.

### Telling Puppet Bindings how Data is Organized

The data in the module is only picked up if there is a `hiera.yaml` file that tells the system
about the layout of the data. By default this file should be placed in the root of the module.

The content of the hiera.yaml file is described with examples; building up from the simplest use case to more advanced. **All of the examples are based on the proposal for 3.4. At the end of this section, there is a [description of the 3.3 format](#wiring-the-33-way). Currently you must be using the version of Puppet on the branch to run these examples.**

#### Simplest - "Private" Hierarchy

With this `hiera.yaml` to the modules's root:

    ---
    version: 3
    hierarchy:
      - 'operatingsystem/${operatingsystem}'
      - 'osfamily/${osfamily}'
      - 'common'

    backends:
      - yaml
      - json

We contribute all of the module's bindings as defaults in the "common" category. You can view this a as a statement about this module's data that says: *"All my data is at 'common' priority in relation to all other contributions. No one else needs to know what my decisions are based on. I simply contribute my default/common values."*

A user of this module does not have to do anything to use it. The 'common' category is always present in the overall hierarchy. 

#### Weaving into the Overall Hierarchy

The simplest way to weave data into the overall hierarchy is to first use the suggested default layout of data (as in all the previous examples where data for say `osfamily`, is found under `data/osfamily/${osfamily}`. Using the same example as in the simple private hierarchy, but now weawing it:


    ---
    version: 3
    hierarchy:
      - category: 'operatingsystem'
      - category: 'osfamily'
      - category: 'common'

    backends:
      - yaml
      - json

As you can see, there is no need to specify the paths if the following is true:

* the used category name is also a variable / fact
* the hiera-2 data files are under `'data/category_name/${category_name}'` where category_name is
  the name given in the list.
* The category is defined at the site level (by default `node`, `operatingsystem`, `osfamily`,
  `environment`, and `common`).
  
What we specified now is that the bindings are contributed per category. You can view this as a statement about the module's data that says: *"My data per category is at the same priority as all other contributions for the same 'site-wide' categories. e.g. My decisions at `osfamily` priority should not override someone else's decision at `operatingsystem` priority"*

Weaving data like this is of value when you:

* want to provide data bindings in a module for the purpose of configuring/overriding other 
  modules
* like to be able to "mix in" decision making about what a value should be either at site 
  level or in another module. 

It is expected that the "private" hierarchy is sufficient in most cases.

#### Advanced Decision Making

Sometimes it is not enough to base the decision on a single variable, or indeed a single path.
Hiera-2 allows specifying multiple paths per category (you have already seen that in the "private hierarchy" example where data on all of the paths where contributed in the common category.

Here is that example spelled out:

    ---
    version: 3
    hierarchy:
      - category: 'common'
        paths:
          - 'operatingsystem/${operatingsystem}'
          - 'osfamily/${osfamily}'
          - 'common'

    backends:
      - yaml
      - json

This has the exact same meaning as in the earlier "private hierarchy" example. 

You can use several paths for any category. Say that you want to control the binding of data based on both `operatingsystem` and `environment` (in a module that is specific to your organization naturally since public modules can not really know about the names of your environments). Having this in an organization specific module makes it easy to mix it in without having to change anything at the site level.

    ---
    version: 3
    hierarchy:
      - category: 'operatingsystem'
        paths:
          - 'env/${environment}/os/${operatingsystem}'
          - 'os/${operatingsystem}'

      - category: 'osfamily'
        paths:
          - 'env/${environment}/osfamily/${osfamily}'
          - 'osfamily/${osfamily}'

    backends:
      - yaml
      - json


You can read this as: *"I contribute data to the shared 'operatingsystem' and 'osfamily' priorities.
My decision what I contribute is based on combinations of environment and operatingsystem/osfamily. Others can view my data as being only based on operatingsystem, because I have already made the decisions, and they do not need to know how I did that."*

#### Even more advanced Decision Making

In this case, a decision is based on the combination of two facts. Only certain combinations require a specific value and you do not want to have a file for each combination. Further, we want this advanced decision making to be woven into a custom category (that we in a flurry of imagination named 'custom').

    ---
    version: 3
    hierarchy:
      - category: 'custom'
        paths:
          - 'combined/${fact1}-${fact2}'
          - 'fact1/${fact1}'
          - 'fact2/${fact2}'
        value: '${fact1}-${fact2}'

    backends:
      - yaml
      - json

You can read this as: *"I have a custom category that is based on two facts. I make decisions based on the combination, or if that does not exists, first on one, then the other fact. Others should view my decisions as having considered both facts at once - i.e. my bindings apply when data is looked up and the shared category 'custom' is defined as `custom = "$fact1-$fact2"`*

See more about the `value` attribute under [Wiring all the Modules](#wiring-all-the-modules).

#### What about multiple paths in multiple categories?

Basically, when you have multiple categories, the functionality compared to hiera-1 is really just that you have tagged certain positions in the list with the category name to contribute to for that section of the list. From the perspective of the module, it is a hierarchy of paths from top to bottom just as if there were no categories involved.

#### Should I always use the "private hierarchy"?

Probably yes, and for most public modules on the forge, even more so.

Weaving is of value when there is a more intimate relationship between modules, when one is used to configure others - in your organization when you want to customize per environment, or if you want to support a configured "stack of modules", and similar scenarios. 

Before the support for data-in-modules, none of these more advanced scenarios could not be packaged up an shared since it meant merging all of the required data definitions into one and the same hiera-1 structure.

#### A simple decision - where is the data?

In the `version: 3` of `hiera.yaml`, the decision where the data is relative to the `hiera.yaml` is broken out into a `datadir` attribute. It defaults to `"data"`. You can also set the `datadir` attribute per category which then overrides the attribute at top level.

    ---
    version: 3
    hierarchy:
      - category: 'common'
        paths:
          - 'operatingsystem/${operatingsystem}'
          - 'osfamily/${osfamily}'
          - 'common' ]

    datadir: 'module-data'
    
    backends:
      - yaml
      - json

In this example, all paths are now appended to `'./module-data/'`.

Here we set the `datadir` for one of the categories:

    ---
    version: 3
    hierarchy:
      - category: 'osfamily'
        paths:
          - 'operatingsystem/${operatingsystem}'
          - 'osfamily/${osfamily}'

      - category: 'common'
        datadir: ''

    datadir: 'module-data'
    
    backends:
      - yaml
      - json

This will use `'./common'{.yaml, .json}` for the `common` category path, and `./module-data/` as 
prefix for the `osfamily` category paths. (The example does not spell out the path for the common category, it defaults to 'common').

Wiring the 3.3 way
---
In the Puppet 3.3 support for data-in-modules:

* There is no support for a "private hierarchy" - only the "weaving" mode is supported
* Since only weaving is supported, the overall hierarchy must list all categories required by
  all modules. This was made worse by the 'operatingsystem'-category not being included by
  default - leading to that the very first thing that was needed was to modify the otherwise fully
  functional default for the overall site's data composition. In turn something that needed to be 
  understood in order to modify it. And this would hit all users, not only the author of data
  in one particular module. (This was really bad).
* There is much redundancy in the format (version: 2) as it requires that everything
  is spelled out.
* There is no `datadir` attribute, each path must contain the full path (relative to hiera.yaml)

This means that the much simpler specification available on the 3.4 branch:

    ---
    version: 3
    hierarchy:
      - 'operatingsystem/${operatingsystem}'
      - 'osfamily/${osfamily}'
      - 'common'

    backends:
      - yaml
      - json


Must be written like this for 3.3 (using weaving):

    ---
    version: 2
    hierarchy:
      - ['osfamily',        '${osfamily}',        'data/osfamily/${osfamily}' ]
      - ['operatingsystem', '${operatingsystem}', 'data/operatingsystem/${operatingsystem}' ]
      - ['common',          'true',               'data/common' ]

    backends:
      - yaml
      - json


Note that the 3.3. format has `version: 2`. (It is still supported on the 3.4 branch to not
break anyone that has already started to experiment). The version:2 format should be viewed as deprecated, and it will be dropped.

The three values in the arrays under hierarchy are "category name", "category value", and "path".
The value is the same as the category name in all cases except for custom categories based on
combined facts (as you saw earlier), and for the common category where it must be set to "true".

Quite frankly, this construct ended up being this way because this was the internal structure.
It is just ugly and makes the specification overly complicated.


Making Use of the Data
---

As shown earlier, there are two schools; using implicit or explicit setting of parameter values.

#### Implicit Style

As you have already seen, with the implicit style, you do not have to change the logic as long as
the bound keys (names) correspond to the names of the parameters in the puppet logic. They are just magically set. (Well not so magic - you have already seen where the rabbits come from).

There really is not much more to say. It works as earlier, only now with data contributed from
a module.

#### Explicit Style

In the explicit style (shown below) we will now make use of the Puppet Bindings systems
`lookup` function which in addition to producing the value, also can assert the data type (i.e. check and fail if data is not of the given type). (If you remember, we earlier had calls to the `validate_string` method to do this, and now we do not need these separate calls to check the data type).

We can now wire the data like this:

    class ntp::params {
      $package_name = lookup('ntp::package_name', 'String')
    }

    class ntp inherits ntp::params {
      package {'ntp':
        ensure => present
        name   => $package_name
      }
    }

### Asserting Type

You can assert:

* The basic data types: `'String'`, `'Integer'`, `'Float'`, `'Boolean'`
* The datatype `'Pattern'` (a regular expression), but there is no way it can be specified using
  only Hiera-2, but it is shown here for completeness.
* The abstract data type `'Number'` = `'Integer'`, or `'Float'`.
* The abstract data type `'Literal'` = `'Number'`, `'Boolean'`, `'String'`, `'Pattern'`
* An `'Array'` which also allow specification of the type of its elements e.g. `'Array[String]'`
* A `'Hash'` which also allow specification of the key and element types e.g. `'Hash[String, Integer]'`
* A `'Collection'` which is `'Array'` or `'Hash'` (irrespective of key and value types)
* The abstract data type `'Data'` which is any of `'Literal'`, `'Array[Data]'`, `'Hash[Literal, Data]'`
* If element type is not specified for an Array, it defaults to  `'Array[Data]'`
* If key and element type is not specified for a `'Hash'` it is `'Hash[Literal, Data]'`, and if only
  one type parameter is given it is used for the value, and the key is `'Literal'` by default.
  
The binding system asserts that the looked up data conforms to the type.

As an example, if you want to assert that the data you are looking up is an Array containing Arrays of Strings:

    lookup('mykey', 'Array[Array[String]]')
    
and you got something else, you will see an error like this:

    incompatible type, expected: Array[String], got: String
    
### Lookup with Default and other Options

The lookup in 3.3. had some deficiencies:

* It returned undef if value was not defined
* It did not support default value

The lookup function in the 3.4 branch has been improved (Redmine ##22574) and now supports a third argument for default value. At the same time, if no default is given, and no value is found an error will be raised.

    lookup('mykey', 'String', 'this is the default')
    
The default value (as well as the other attributes) can now be given in the form of a hash. (If you are not using future parser, you need to assign the hash to a variable before passing it, in the future parser, the hash can be given directly.

    lookup({ name => 'mykey', type => 'String', default => 'this is the default'})
    
It is possible to pass the name as an individual argument, and the rest as options (in the
case there is also a name in the options, the individual argument wins:

    lookup('mykey', { type => 'String', default => 'this is the default'})

Note that if a hash is given as the third argument then this is a default value, not options.

The options are:

* `name` - the name/key to lookup
* `type` - the type
* `default` - the default value
* `first_found` - an array of names/keys, tried in order until one has a value. May not be combined 
  with specifying `name`.
* `accept_undef` - whether an undefined lookup is an error or not if the lookup found no value, and 
  there is no default value.

    
Wiring all the Modules
-----
And we have arrived at the final step; wiring all the data(-bindings) from all the modules together with site level data (or possibly additional levels that you defined for your organization).

Specifying how everything works together is done in the file `binder_config.yaml` in the `$config_dir`. It tells the Puppet Binding system:

* the **priority** of the sources (should site level override modules?, is 
  there a difference between in-house modules and public modules?, etc.)
* which sources of data(-bindings) to **include**, and which to **exclude**
* if there are any custom providers of data(-bindings)

The `binder_config.yaml` looks like this:

    ---
    version: 1
    layers: [
        - name: 'site',
          include:
            - 'confdir-hiera:/'
            - 'confdir:/default?optional'

        - name: 'modules',
          include:
            - 'module-hiera:/*/'
            - 'module:/*::default'
    
    categories:
      - name: 'node'
        value: "${fqdn}"
      - 'operatingsystem'
      - 'osfamily'
      - 'environment'
      - 'common'


The above is the default, which is used if we do not have this file at all. Also if we have
this file, but do not specify the sections for `layers`, or `categories`, we get the default as shown above.

* The `layers` is an array ordered from highest priority to lowest. The default places the site layer
  at a higher priority than the module layer.
* The name of the layer is used in error message, and as an identifier for the
  human reader, it has no other technical significance.
* The `include` attribute
  * specifies which data(-bindings) contributions to include 
  * can contain one URI string, or an Array of URI Strings (explained further below)
* The `exclude` attribute
  * specifies which data(-bindings) contributions to exclude (from those that were included) 
  * can contain one URI string, or an Array of URI Strings. (explained further below)
* The `categories` specifies:
  * The priority between the site wide categories (i.e. *the names of hierarchical levels* if
  we use Hiera-1 terminology). The highest priority is at the top.
  * The categories `'node'`, `'operatingsystem'`, `'osfamily'`, `'environment'`, and `'common'`
    are always present; they are added if left out of the specification. If included, they must have 
    the relative order  
    'node' > 'environment' > 'operatingsystem' > 'osfamily' > 'common'.
    It is allowed to add new categories between these.
  * The *name* of the category (e.g. 'node', 'common') - these names are the categories that can
    be used in the module contributions being composed.
  * The *category-value* - this determines what the category value will be set to when processing a 
    request.
  * If only the category name is specified (as a String), the value defaults to interpolation of
    a variable with the same name as the category.
  * To specify both the category name and value, either use an array with `['name', 'value']`, or an 
    object with `name: 'name', value: 'value'`.
    
#### The category-value Explained in Detail

The meaning of the category value requires a bit more explanation. In the typical use case
(modules contribute data in the common category based on decisions from a private hierarchy when a request is made for a catalog) the more detailed meaning of category-value is not a concern in practice, and you can safely skip this section.

If you are inventing your own site-wide categories or have organization specific modules
that contribute bindings per `node` you should read this section.

For all of the default categories  (except `'node'`), the category-value is simply the value of the corresponding fact variable (for `'node'` the value is `${fqdn}`). This value is set when a request is processed - e.g. when a request to compile a catalog is made.

The bindings system assigns the category values from the facts in the request. As an example, using the default configuration for `binder_config.yaml` and this set of facts:

* `$fqdn = 'kermit.example.com'`
* `$operatingsystem = 'Gentoo'`
* `$osfamily = 'Linux'`
* `$environment = 'production'`

the resulting category-values (used internally by the Puppet Bindings system) becomes:

* `category['node']            = 'kermit.example.com'`
* `category['operatingsystem'] = 'Gentoo'`
* `category['osfamily']        = 'Linux'`
* `category['environment']     = 'production'`
* `category['common']          = true` # (it is always true)

Then, if we have a `hiera.yaml` like this:

    ---
    version: 3
    hierarchy:
      - category: 'osfamily'
        paths:
          - 'operatingsystem/${operatingsystem}'
          - 'osfamily/${osfamily}'

And we have data like this:

    <module>
    |-- data                       #  Where all the data is kept
    |   |-- osfamily               #  Data per osfamily
    |   |   |-- FreeBSD.yaml       #  Data for FreeBSD
    |   |   |-- . . .              #  etc.
    |   |-- operatingsystem        #  Data per operatingsystem
    |   |   |-- Gentoo.yaml        #  Data for Gentoo


The resulting data binding corresponds to a 'conditional binding' (here expressed in pseudo code):

    if category['osfamily'] == 'Linux' {   # since it is contributed to the osfamily category
      ntp::package_name = 'net-misc/ntp'   # the content in Gentoo.yaml
    }

While this is in sort of lying; the ntp package name is not `'net-misc/ntp'` for all operating 
systems in the Linux os-family, **it is still true for this (catalog) request**!

Remember that Hiera bindings can really only be resolved once a set of facts are known.
Specifically, the search paths used in Hiera-2 to make a decision what a value should be, have been resolved at the time the bindings from all sources are combined.

Since the bindings system computes the result for each request it does not matter in practice that the statement is not universally true. The only thing we cannot do is to save the result and use it
for another request with a different set of facts).

To correct our "universal" lie, we can simply change the `hiera.yaml` to read:

    ---
    version: 3
    hierarchy:
      - category: 'operatingsystem'
        paths:
          - 'operatingsystem/${operatingsystem}'
          - 'osfamily/${osfamily}'

What happens now is that the contribution from the module results in:

    if category['operatingsystem'] == 'Gentoo' { # since it is contributed to operatingsystem
      'ntp::package_name' = 'net-misc/ntp'       # the content of Gentoo.yaml
    }

Which *is* universally true. It will also be true for all other requests even if the decision
is made based on `osfamily` since the result is bound conditionally to the value of `$operatingsystem`.

Thus, as a simple rule of thumb; **Avoid universal lies by contributing to a category based on the highest priority variable used in your paths.**

In summary:

* You only need to specify the category value of a category in `binder_config.yaml` or `hiera.yaml` 
  if it is different than the value of the variable with the same name as the category. If it is 
  different it must be stated the same way in all places the category is used - since this is 
  effectively the definition of the category - and the same definition must be used everywhere (or 
  the bindings will not take effect).

* If you invent a custom category, it should use a category value that reflects the most specific 
  value used in making the decision. (We saw an example of this earlier when combining two facts into
  a value of `"${fact1}-${fact2}"`).


#### Differences from 3.3.0

This format is somewhat simplified from the 3.3.0 supported format:

* A category that is named the same as a fact variable does not have to specify the value.
* Consequently, if you are using the 3.3.0 version, you need to specify each category with an array 
  containing the category name, and the value.
* The 3.4 format supports either a String (the name), and Array ([name, value]), or an object
  {name: 'name', value: 'value'}.

#### When do I have to change the binder_config?

The default shown in the previous section should give you quite a lot of milage. It picks up all contributions from modules written using Hiera-2 and it picks up all contributions written in Ruby.
It defines that the site level data should override anything that comes from modules. It also has a default set of categories.

This is enough to start experimenting. You only need to change this file:

* to define additional layers (maybe you want in-house modules to be able to override public/forge 
  modules).
* if you want to manually list modules and not rely on wild cards (maybe you want things locked down
  in production)
* if you want to add custom categories
* If you want to exclude certain modules / sources
* if you want to integrate data from other sources (i.e. adding a custom scheme)
* if you want to use custom hiera-2 backends

You have already seen how the categories are specified and used in `binder_config.yaml`, and in hiera.yaml. For inclusion and exclusion, which is based on URIs you need to learn more about the schemes used to refer to the various sources of bindings.

Thus, examples showing inclusion and exclusion are presented later. (TODO: PROVIDE LINK).

Schemes
-------
We need a way to refer to different sources of bindings. In this document we concentrate on
data in modules where the data is expressed using Hiera-2, but there are, and will be other sources
such as external services (e.g. ENC) that can be directly integrated. We also want an identity of a
set of contributed data that continues to work when sources are something other than modules.
We could also add support for file and ftp schemes that read serialized bindings models (which could be useful when testing, or as optimization / caching).

For these reasons, a decision was made to use a URI (Universal Resource Identifier). While you are not yet familiar with the particular schemes used by Puppet Bindings, the fundamental idea of a URI, its syntax, and the basic laws of URIs should be familiar to everyone.

This section explains in more detail how the schemes work. The advanced topic 'how to write a custom scheme' is covered in  [ARM-9](https://github.com/puppetlabs/armatures/blob/master/arm-9.data_in_modules/index.md#custom-bindings-scheme-handler)

The URI is specific to the used scheme - i.e. it is the creator of a scheme that decides the meaning of the various sections of the URI. As you will see below, the schemes provided by default are either based on a symbolic name (i.e. the module name), or a path. A custom scheme may use the URI syntax for query parameters, etc.

In the first implementation there are four such schemes:

- `confdir-hiera:`
- `module-hiera:`
- `confdir:`
- `module:`


### Hiera-2 Schemes

The `confdir-hiera` scheme is used with a path that is relative to the *confdir*. The path should appoint a
directory where a `hiera.yaml` file is located. If the `hiera.yaml` for the site is located in the same directory as
the `binder_config.yaml`, the entry would simply be `confdir-hiera:/`

The `module-hiera` scheme is used with a path where the first entry on the path is the name of the module,
or a wildcard `*` denoting all-modules. When using the wildcard, those modules that have a `hiera.yaml` in
the appointed directory will be included (those that do not are simply ignored). The path following the module name
is relative to the module root.

Thus, the URI `module-hiera:/*` uses the `hiera.yaml` in the root of every module. The URI `module-hiera:/*/windows`
loads from every modules' `windows` directory, etc.

It is expected that `include` is used with broad patterns, and that a handful of exclusions are made (for broken/bad module
data, or data that simply should not be used in a particular configuration).

When the URI contains a wildcard, and there is no `hiera.yaml` present that entry is simply ignored. When an explicit URI is used it is an error if the config file (or indeed the module) is missing.

Also see [Optional Inclusion](#optional-inclusion).

### Module / Confdir Schemes

In the first release of data-in-modules, the `module` and `confdir` schemes are only used to refer to bindings made in Ruby.
In later releases these schemes will be used to also refer to bindings defined in the Puppet Language
(as explored in ARM-8 Puppet Bindings). 

If you are interested in Ruby bindings, please see the corresponding section in [ARM-9](http://links.puppetlabs.com/arm9-data_in_modules)

### Optional Inclusion

To make inclusion more flexible, it is possible to define that an (explicit) URI is optional - this 
means that it is ignored if the URI can not be resolved. The optionality is expressed using a URI 
query of `?optional`. As an example, if the module ‘`devdata`’ is present its contributions should be 
used, otherwise ignored, is expressed as:

    module-hiera:/devdata?optional

This can be used to minimize the amount of change to the `binder_config.yaml` and allowing the
configuration to be dynamically changed depending on what is on the module path. As an example
a developer can check out a `devbranch` with experimental overrides without having to restart the master. 

Hiera-2 Backends
---
This is an advanced topic that can be safely skipped.

Hiera-2 backends are far simpler to implement than the corresponding Hiera-1 backends. This because the contract in Hiera-2 is for the backend to return a hash of name to value while the backend is
responsible for the search itself in Hiera-1.

The details how to write a hiera-2 backend are presented in ARM-9 in the section [custom hiera-2 backend](https://github.com/puppetlabs/armatures/blob/master/arm-9.data_in_modules/index.md#custom-hiera-2-backend).

ARM-9 also discusses the various options for integrating data bindings in various forms. As an example, bindings in Ruby, as well as scheme handlers provide a far more powerful way of handling data.

Specifying Custom Schemes, and/or Hiera-2 Backends
---
This is an advanced topic that can be safely skipped.

If you have implemented a custom scheme, or a hiera-2 backend these must be added to the binder_config.yaml. The custom schemes may then be used in the specification of what to include/exclude in the binder_config.yaml's layers specification. Likewise, any custom hiera-2 backends may then be used in the various `hiera.yaml` files in the system.

This means that currently, a module can not use a custom scheme unless it is added to the binder_config.yaml. This may change in the future.

The specification of these is quite simple:

    extensions:
      hiera_backends:
        custom1: 'name of class'
        custom2': 'name of class'
    
      scheme_handlers:
        custom1: 'name of class'
        custom2: 'name of class'
        
Using the example from ARM-9 (where a module named 'Awesome' contains a backend called
EchoBackend, and a scheme called EchoScheme):

    extensions:
       hiera_backends:
          echo: 'Puppetx::Awesome::EchoBackend'
          
       schema_handlers:
          echo: 'Puppetx::Awesome::EchoScheme'


Applying what we Learned
-----

### Testing the ntp Example binder_config

In our ntp example from the start of the document, we can use the default binder_config.yaml so we can start testing it right away.

We simply need to turn on the binder feature using `--binder true` as a setting, or on
the command line. (Alternatively, if `--parser future` is used, the binder is also turned on by default).

We can now test this on the command and lookup the ntp::package value:

    puppet apply --binder -e 'notice lookup("ntp::package_name")'
    
This will lead to an error since the facts are not known. Unless you are indeed running on FreeBSD, or Gentoo you will see the error:

    Error: did not find a value for the name 'ntp::package_name' on node 'demo.example.com'
    
Naturally Since the decision is based on `operatingsystem` (Gentoo) and `osfamily` (FreeBSD and Linux) we need to also supply those facts. This can be done this way (all on one line):

    FACTER_OPERATINGSYSTEM=Gentoo FACTER_osfamily=Linux puppet apply -e 'notice lookup("ntp::package_name")'
    
And we should now see the expected result:

    Notice: Scope(Class[main]): net-misc/ntp

If you need many facts to test, you can set all of the required environment variables and export them before executing. How this is done depends on the shell you are using.

In bash you can set and export variables like this:

    FACTER_OPERATINGYSTEM=Gentoo
    FACTER_OSFAMILY=Linux
    export FACTER_OPERATINGSYSTEM FACTER_OSFAMILY

You may want to do this in a sub-shell so these exports do not override your regular set of facts.

### Excluding a Module

We find that one of our module (aptly named 'batboy') contributes data that is not what we want. Or worse, that there are syntax errors in its hiera.yaml. If we want to exclude the contribution from 'batboy' we can do su by modifying the binder_config.yaml.

We want to use the defaults for categories, so we only include the layers specification:

    ---
    version: 1
    layers: [
        - name: 'site',
          include:
            - 'confdir-hiera:/'
            - 'confdir:/default?optional'

        - name: 'modules',
          include:
            - 'module-hiera:/*/'
            - 'module:/*::default'
          exclude:
            - 'module-hiera:/badboy/
            
The contribution from the module 'badboy' that was included by the URI 'module-hiera:/*/' is excluded by the rule module-hiera:/badboy/ and no attempt is then made to read it's hiera.yaml (nor is the data included).

If we also want to exclude its ruby bindings we do that like this:

          exclude:
            - 'module-hiera:/badboy/
            - 'module:/badboy::default

### Selecting an alternative set of bindings

A module (called 'awesome') may include alternative set of bindings configured for different usage scenarios.

    awesome
    |-- hiera.yaml
    |-- data
    |-- |-- default
    |   |   |-- common.yaml
    |-- |-- for_x
    |   |   |-- hiera.yaml
    |   |   |-- data
    |   |   |   |-- common.yaml
    |-- |-- for_y
    |   |   |-- hiera.yaml
    |   |   |-- data
    |   |   |   |-- common.yaml

And we we would like to use the 'for_x' bindings instead of the default bindings. We then exclude the default, and include the 'for_x' like this:

          include:
            - 'module-hiera:/awesome/data/for_x
          exclude:
            - 'module-hiera:/awesome/
            
In this example, the for_x was placed under 'data', but it could be located anywhere we like in the module. The path we specify after the module name, is relative to the root of the module.

Naturally, you need to consult the documentation of the module in question which alternative sets it provide, if it provides a default and the intention is to use both (default and a special set), or of the default must be excluded.

### Overriding a value at site level

If you want to override a value set in a module with one at the site level, you can set the value in the site's hiera-2 data. This set of data is included by default (as long as the `hiera.yaml` version in the root of the site is of version 2 or 3.

The structure you use in your hiera, depends on what you need to base the decision on.

If you want to override for a given node:

The structure:

    <confdir>
    |-- hiera.yaml
    |-- data
    |-- |-- node
    |   |   |-- kermit.example.com.yaml

The hiera.yaml:

    hiera.yaml
    ---
    version: 3
    hierarchy:
      - node/${fqdn}
    
    backends:
      - yaml 
 
 
FAQ
===
### Can I access variables in the calling scope?

No, only top scope variables set from facts and settings are available for interpolation.

### Is the data in a module private to that module?

No, data is bound to keys that are in a flat namespace. All names should be fully qualified with module name to ensure that they do not clash. As a module author you own the module's namespace.

This is an area of future improvement. It would be great if a module could declare that
it only assigns data to keys in its own namespace, or to keys that exist for the purpose of
collecting information from other contributors. That way the system can enforce these rules. For modules that contain configuration for others, the user integrating such a module would need
to know what it does (or trust it because it is internal to the organization).

### Can a hierarchy be private to a module

Yes, only the decisions that were made by using a hierarchy of paths are visible. The
data bindings are not private.

### Can I secure the values some way?

Currently only somewhat secure. Once the values are bound, they can be looked up by any logic that 
knows the name. Likewise, the resulting value is placed in a resource (and thus in catalog) and can be read from there in various ways.

While it is possible to have implement a secure backend that reads encrypted data on disk, this
is not completely safe since the values are decrypted when they are used, and the used values are
stored in the catalog.

To have completely secure data means it needs to be encrypted all the way and the reader must have the means to decrypt it. Support for this may appear in puppet in the future. If you want to implement this now, you need to have a provider for a type and having this provider perform the decryption on the agent. (Thus never placing the clear text value in the catalog). 


### Can I interpolate the values of other keys?

Yes, you can call the lookup function in interpolation.

### Can I use any expression in interpolation?

Yes, the Puppet Binder uses the future parser and it allows any expression that may appear in conditional logic (i.e. not class, define and resource expressions) to be used
in interpolation.

If you want to use this, you should use a version of puppet that includes a fix for Redmine issue #22593. (The 3.4 branch of the data in modules includes this fix).


### Can I add Hiera-2 backends?

Yes, but there are also other options that give you more power. You can write bindings in Ruby,
and you can provide a scheme handler. These options are discussed in ARM-9.

A Hiera-2 backend is different from a Hiera-1 backend. It is also much simpler to implement as
it basically just needs to return a hash.

See [Hiera-2 backends](hiera-2-backends) in this document.

### What are the performance implications?

Performance tuning of the feature has not taken place yet. This will be done before 'data in
modules' is released.

Backgound
-----

### What is 'armatures'?

The [Puppet Armatures](https://github.com/puppetlabs/armatures/blob/master/README.md) is a process for having an open process for the community where
collaboration on larger ideas regarding something in the Puppet echo system can take place. It exists in the form of a github repository with documents describing the process itself, the ideas (armatures) and templates for creating such documents).

### What is the relationship between ARM-9, and ARM-8?


The ideas and technical details for 'Data in Modules' are described in [ARM-9](http://links.puppetlabs.com/arm9-data_in_modules). ARM-9 is in turn based on the ideas described in [ARM-8 Puppet Bindings](http://links.puppetlabs.com/arm8-puppet_bindings). 

ARM-9 has a broader scope as the "composing data from multiple modules" is only one of several use cases where there is the need to compose/configure a puppet system's behavior. This ranges from
purely internal logic in puppet, how to support an external node classification service that also
gives users the ability to control all configurable aspects of the puppet system, to being able to supply plugins to the puppet runtime. All these have similar problems regarding separation of concerns as when composing data and parameters in puppet modules.

To facilitate these additional requirements without having to have multiple system that deals with "data-binding" (or to generalize deals with "binding of data and code"), the 'data in modules' support was based on a new *Puppet Bindings* system. The full technical description of the Puppet Bindings system can be found in [ARM-8](http://links.puppetlabs.com/arm8-puppet_bindings).

The 'data in modules'  is the full technical description of the 
also includes an implementation of what is called Hiera-2 which is an evolution of the Hiera style of defining
hierarchical data adapted to work using the bindings system.

### What is Puppet Bindings?

Puppet Bindings is the technical underpinnings on which 'Data-in-Modules' is built. It is a mechanism
for *dependency injection* (i.e. implicit and explicit "lookup" of composed bindings of data and code). It is described in [ARM-8](http://links.puppetlabs.com/arm8-puppet_bindings). Be warned that it is not an easy read, and ARM-8 includes several aspects of dependency injection that are not directly relevant to data in modules, many which are purely internal to the puppet runtime, others that are of interest to integrators.

### Is there some lighter reading about Puppet Bindings than ARM-8?

Not currently, but there will be developer introduction and documentation available when Puppet Bindings is no longer experimental. 