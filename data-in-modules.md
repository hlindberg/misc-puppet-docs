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
  
Let's look at what the solution looks like (for both cases). We invent the module `romulan` (they are not known for the adherence to logic) that has osfamily and operatingsystem reversed. We could then do this.

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

* We may have hundreds of modules! Some written by "romulans" and we end up with a long list and
  lots of searching for data.
* This is however a lesser evil than copying the romulan module settings and the ntp settings into 
  the same file (e.g. `operatingsystem/FreeBSD.yaml`). This is particularly bad if someone later
  deciders that the data in the FreeBSD.yaml file can be refactored/optimized by intermingling
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
one of the validate_<type> functions in the standard library:

    class ntp($package_name) {
      validate_string($service_ensure)
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
  validate_string($service_ensure)
  package {'ntp':
    ensure =&gt; present
    name   =&gt; $package_name
  }
}
</pre></td>
<td><pre>
class ntp::params {
  $package_name = hiera('ntp::package_name')
  validate_string($service_ensure)
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
  levels and flea market of small data files since we need to solve the issues of every module
  in one place.
* We must manually maintain this structure as modules change.
* We must manually maintain this structure as we add or remove modules

Possible work arounds for some of the problems, but none of them are very appealing:

* We could point directly to the data in modules (and not having to copy the data), this makes
  it easier to get upgrades but requires that modules are always located at the same relative
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
A number of issues have already been raised and solutions have been described. These issues
are noted in this document.

### Main Features

In short, Data in Modules does the following:

* It allows you to directly use the data inside of the module. The data does not have to be
  copied and maintained in a central location.
* The inclusion (and exclusion) are controlled by patterns so you do not have to change the
  configuration as modules are added or removed (unless there is something wrong or special you
  want).
* You are given control over how the data from modules is composed and arranged in relation to
  other sources e.g. site level data overrides module level data.
* Data bindings can be expressed in Hiera-2, or in Ruby.
* A module (and the site/environment) may have multiple sets of data to allow a configuration
  to select the suitable data sets. This an be used for several purposes; allowing modules to
  supply defaults for different common configuration types, allow a module to be created for the sole 
  purpose of contributing different kinds of configuration for a combination of modules (i.e. a kind 
  of higher order module like a "lamp-stack" which in itself does not contain much functionality but 
  it may configure the modules it depends on)

### Hiera-2 Features

There are two major differences between Hiera-1 and Hiera-2

* Hiera-2 uses Puppet Language syntax for interpolation of expressions - i.e. `${expression}`, where
  Hiera-1 only supported interpolation of variables, and with a different syntax `%{varname}`.
* The `hiera.yaml` configuration file has changed
    * variables are interpolated using Puppet Language syntax
    * since the result is contributed to an overall configuration of data, there is the need
      to specify how.
* Hiera-2 loads dynamically, if the hiera.yaml is changed these changes are picked up when processing
  the next request (e.g. for a catalog).

Introducing data-in-modules presented an opportunity to also address general issues. Hiera-1 only allows interpolate of variables and uses a different interpolation syntax (`%{varname}`) than the Puppet Language (`${expression}`).

In Hiera-2 any interpolateable Puppet expression can be used, including function calls. The string
is treated like a Puppet Language double quoted string, which means that escaping special characters is also possible.

The other notable change is to the `hiera.yaml` required to make it possible to compose/aggregate multiple hierarchies.

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
(or `$varname`). We also need to look at the user of a literal `$` since it needs to be escaped. While doing this, attention is also needed to the backslash `\` character as it is now used for escaping. In short - Hiera-2 uses the same rules as for the Puppet Language double quoted string.

### Telling Puppet Bindings how Data is Organized

The data in the module is only picked up if there is a `hiera.yaml` file that tells the system
about the layout of the data. By default this file should be placed in the root of the module.

So we add this `hiera.yaml` to the modules's root:

    ---
    version: 2
    hierarchy:
      - ['osfamily',        '${osfamily}',        'data/osfamily/${osfamily}' ]
      - ['operatingsystem', '${operatingsystem}', 'data/operatingsystem/${operatingsystem}' ]
      - ['common',          'true',               'data/common' ]

    backends:
      - yaml
      - json


Since we are not using any data in `json`, we can remove that entry. It is only shown here to point out that you can also use data files in Json format. (See [FAQ](#FAQ) for more information about
backends).

By looking at the file we see three things:

* The format of the file is versioned, currently at version 2.
* Puppet Language string interpolation is used. And thirdly, the hierarchy is specified with a  
  slightly more elaborate structure where each entry in the hierarchy have three values (instead of  
  Hiera-1's one path value). This is explained below.
* The paths work the same way as in Hiera-1, but use Puppet Language interpolation.

*Note that feedback have been received  about what seems like redundant information, and
that the three elements have no attribute names associated with them which makes it
hard to guess what the meaning is. There is a proposal that reduce the amount of text
that needs to be entered to a minimum. At the moment, the experimental implementation requires the
somewhat elaborate specification as shown in this document.*


### Why the three data elements?

#### The first element - the category

Imagine trying to combine the data contributions from two modules with the following (Hiera-1) hierarchies:

    hierarchy:
      - 'data/%{DCR_nbr}'
      
    hierarchy:
      - 'data/moduledata'

Which of the two bindings should have higher priority when they are combined, or are they at the
same priority? To solve this we need to give the level a name. 

This name is the first element.

Thus: **We need the first element to allow us to add the individual pieces at the right level
in the final hierarchy.**

We use the term **category** for the "name of the hierarchical level".

#### The second element - the category value

The second element requires a longer explanation.

If we look at an entry such as this:

      - ['osfamily',        '${osfamily}',        'data/osfamily/${osfamily}' ]

has lots of redundant information. In fact we could do away with the path for all paths
following the formula typical used; the data is in the data directory, under a directory named after
the category, and then in a file with a name matching the category value. 
This simplification is not yet implemented, in the first implementation (Puppet 3.3.0) all three has to be given - but this will be improved.

We still need the third path element when a Romulan have defined the structure differently.
Some may have their data to first switch on osfamily, and then have different values per environment - e.g.

      - ['osfamily',        '${osfamily}',        'data/osfamily/${osfamily}/${environment'} ]

Or they want to reference a file with data while testing that is named after something
completely different - say the issue they are working on, and you find an entry like:

      - ['osfamily',        '${osfamily}',        '/usr/mary/devdata/issue475' } ]

Thus, removing the entry that specifies the value - it would not possible to (always) use the file name referenced by the path.

Another future improvement is to remove the need to specify the common category with the value
true and a path, one value 'common' should be enough here. 

      - ['common',        'true',        'data/common' ]

The term **category-value** was chosen for this second element. This value typically
comes from a fact (such as the value of `$osfamily`), but it could also come from an expression such as a function call that determines a) if the category applies to the request or not, and b) what the value is.

As an example, you may have something like a rack number, and you would like to specify
a binding for racks 1-10 that are different from racks 11-20, etc. You can perhaps get the
rack number from a fact, or by looking it up in a system that keeps a mapping from some fact(s)
to rack-number. If you were not able to use a function you would need to write 20 data files, one
per rack-number. You call this category rack_bay, and the function returns a value 1 for the first
bay, 2 for the second etc. (Unfortunately in the first implementation you have to repeat the
call for the path)

     - ['rack_bay', '${bay_of_rack($rack_number)}', 'data/rack_bay/${bay_of_rack($rack_number)}']
      
If the function determines that the request being processed is not for a host in a rack at all,
it simply returns an empty string to mean, "it is not in this category at all".

Thus: **We need the second value to give us the value to match on since we cannot derive it
from the other two (name and path) at all times**

#### The third element - the path

Unsurprisingly, this element is needed to refer to the file that contains the data.
(As you saw above, we could do away with the path if the structure follows the typical formula).


### Making Use of the Data

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
  Hiera-2, but it is shown here for completeness.
* The abstract data type `'Number'` = `'Integer'`, or `'Float'`.
* The abstract data type `'Literal'` = `'Number'`, `'Boolean'`, `'String'`, `'Pattern'`
* An `'Array'` which also allow specification of the type of its elements e.g. `'Array[String]'`
* A `'Hash'` which also allow specification of the key and element types e.g. `'Hash[String, Integer]'`
* A `'Collection'` which is `'Array'` or `'Hash'` (irrespective of key and value types)
* The abstract data type `'Data'` which is any of `'Literal'`, `'Array[Data]'`, `'Hash[Literal, Data]'`
* If element type is not specified for an Array, it defaults to  `'Array[Data]'`
* If key and element type is not specified for a `'Hash'` it is `'Hash[Literal, Data]'`, and if only
  one type parameter is given it is used for the value, and the key is `'Literal'` by default.
  
The binding system can assert that the data conforms to the type.

As an example, if you want to assert that the data you are looking up is an Array containing Arrays of Strings:

    lookup('mykey', 'Array[Array[String]]')
    
and you got something else, you will see an error like this:

    incompatible type, expected: Array[String], got: String     
    
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
        { 'name': 'site',
          'include': ['confdir-hiera:/', 'confdir:/default?optional']  
        },
        { 'name': 'modules',
          'include': ['module-hiera:/*/', 'module:/*::default']
        }
      ]
    
    categories:
      [['node',        "${fqdn}"],
       ['osfamily',    "${osfamily}"],
       ['environment', "${environment}"],
       ['common',      "true"]
      ]

The above is the default, which is used if we do not have this file at all. Also if we have
this file, but do not specify the sections for layers, or categories, we get the default as shown above.

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
  * The categories `'node'`, `'environment'`, `'osfamily'` and `'common'` are always present;
    they are added if left out of the specification. If included, they must have the relative order 
    'node' > 'environment' > 'osfamily' > 'common'.
    It is allowed to add new categories between these.
  * The *name* of the category (e.g. 'node', 'common') - these names are the categories that can
    be used in the module contributions being composed.
  * The *category-value* - this determines what the category value will be set to when processing a 
    request.

*Note that people have raised issues about the format not being human friendly and
that named attributes should be used to a greater extend. There is a propoal how this
should be done. At the moment, the experimental implementation requires the somewhat elaborate specification as shown in this document.*

#### When do I have to change the binder_config?

The default town in the previous section should give you quite a lot of milage. It picks up all contributions from modules written using Hiera-2 and it picks up all contributions written in Ruby.
It defines that the site level data should override anything that comes from modules. It also has a default set of categories.

This is enough to start experimenting. You need to change this file:

* to define additional layers (maybe you want in-house modules to be able to override public/forge 
  modules).
* if you want to manually list modules and not rely on wild cards (maybe you want things locked down
  in production)
* if you want to add categories
* if you want to integrate data from other sources (adding a custom scheme)


Schemes
-------
We need a way to refer to different sources of bindings. In this document we concentrate on
data in modules where the data is expressed using Hiera-2, but there will be other sources
such as external services (e.g. ENC) that can be directly integrated. We also want an identity of a
set of contributed data that continutes to work when sources are something other than modules.
We could add support for file and ftp schemes that read serialized bindings models (which could be useful when testing, or as optimization / caching).

For these reasons, a decision was made to use a URI (Universal Resource Identifier). While you are not familar with the schemes used by the binder, the fundamental idea of a URI, its syntax, and the basic laws of URIs should be familiar to everyone.

This section explains in more detail how the binder schemes work. The more advanced aspects are discussed in  [ARM-9](TODO://URL)

The bindings provider URI is specific to the used scheme. In the first implementation there are four such schemes:

- `confdir-hiera`
- `module-hiera`
- `confdir`
- `module`

It is possible to add custom schemes.


### Hiera-2 Schemes

The `confdir-hiera` scheme is used with a path that is relative to the *confdir*. The path should appoint a
directory where a `hiera.yaml` file is located. If the `hiera.yaml` for the site is located in the same directory as
the `binder_config.yaml`, the entry would simply be `confdir-hiera:/`

The `module-hiera` scheme is used with a path where the first entry on the path is the name of the module,
or a wildcard `*` denoting all-modules. When using the wildcard, those modules that have a `hiera.yaml` in
the appointed directory will be included (those that do not are simply ignored). The path following the module name
is relative to the module root.

Thus, the URI `module-hiera:/*` uses the `hiera.yaml` in the root of every module. The URI `module-hiera:/*/windows`
loads from every modules' windows directory, etc.

It is expected that `include` is used with broad patterns, and that a handful of exclusions are made (for broken/bad module
data, or data that simply should not be used in a particular configuration).

When the URI contains a wildcard, and there is no `hiera.yaml` present that entry is just ignored. When an explicit URI is used it is an error if the config file (or indeed the module) is missing.

Also see [Optional Inclusion](#optional_inclusion).

### Module / Confdir Schemes

In the first release of data-in-modules, the `module` and `confdir` schemes are only used to refer to bindings made in Ruby.
In later releases these schemes will be used to also refer to bindings defined in the Puppet Language
(as explored in ARM-8 Puppet Bindings). 

If you are interested in Ruby bindings, please see the corresponding section in [ARM-9](http://links.puppetlabs.com/arm9-data_in_modules)

### Optional Inclusion

To make inclusion more flexible, it is possible to define that an (explicit) URI is optional - this means that it is
ignored if the URI can not be resolved. The optionality is expressed using a URI query of `?optional`. As an example,
if the module ‘`devdata`’ is present its contributions should be used, otherwise ignored, is expressed as
`module-hiera:/devdata?optional`.

This can be used to minimize the amount of change to the binder_config.yaml and allowing the
configuration to be dynamically changed depending on what is on the module path. As an example
a developer can check out a devbranch with experimental overrides without having to restart the master. 


Applying what we Learned
-----

### The ntp Example binder_config

In our ntp example, we used a category called `operatingsystem`. Unfortunately, the default
`binder_config.yaml` does not contain this category, and if we tried to run this we would
get an error.

    TODO Show the error.

Since the categories used in the modules must be present in the `binder_config.yaml` we add it like this:

    categories:
      [['node',            "${fqdn}"],
       ['osfamily',        "${osfamily}"],
       ['operatingsystem', "${operatingsystem}"],
       ['environment',     "${environment}"],
       ['common',          "true"]
      ]

The reason all used categories must be in this list is that all data from all modules are in a flat space and everyone must agree on priority or there would be chaos (again sorry, Romulans). (For the Romulans in the audience (and also for other good reasons) there is a discussion about supporting "private data" - see [Private Module Data](#private_module_data) below).

Issues With current implementation
===
Since data-in-modules where made available as an experimental implementation in Puppet 3.3 people
have been asking questions, describing their needs and given critique. 

* The files are not human friendly - use attributes
* There is much redundancy in the typical case
* Modules need to be able to have their own hierarchy to be both self contained and configurable
* The lookup function needs to handle defaults (and have some additional features like 'first-found' 
  given a list of keys)
 
This is described, along with proposed solutions in an adjoining document called 'improvements-arm-9.md' (This [link](improvements-arm-9.md) may work depending on where/how you consume this document)
 
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

### Can I interpolate the values of other keys?

Yes, you can call the lookup function in interpolation.

### Can I use any expression in interpolation?

Yes, the Puppet Binder uses the future parser and it allows any expression that may appear in conditional logic (i.e. not class, define and resource expressions) to be used
in interpolation.

(There are some recently discovered issues found regarding use of expression with nested braces)
[# nnnn](TODO: Reference to Redmine issue)

### Can I add Hiera-2 backends?

Yes, but there are also other options that give you more power. You can write bindings in Ruby,
and you can provide a scheme handler. These options are discussed in ARM-9.

A Hiera-2 backend is different from a Hiera-1 backend. It is also much simpler to implement as
it basically just needs to return a hash.

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
for *dependency injection* (i.e. implicit and explicit "lookup" of composed bindings of data and code). It is described in [ARM-9](http://links.puppetlabs.com/arm9-data_in_modules)