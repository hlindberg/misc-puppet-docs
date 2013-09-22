Private Data in Modules
=======================
Some modules have an requirements on an internal / private way of binding data using its own private hierarchy and mechanisms for binding keys to values. The key feature here is that the structure of this data is private to the module, externally it is possible to override the keys/parameters but then based on decisions in a hierarchy/using categories that are applicable at the site level and across all modules. As an example, one module may use a custom fact and need to use this in its hierarchical data. Without a private hierarchy, this "private category" would need to be configured and placed in relation to all other categories. While doable, this is not desirable when a module has complex needs.

The Puppet bindings system (ARM-9 'data in modules') combines all bindings from all sources into an overall hierarchy, and in this article it is shown how you can support a private data hierarchy by using the binding systems Ruby integration in combination with Hiera-2 data.

This is an advanced example that is fully functional. As you see at the very end, it is proposed that this is packaged up and included in an easy to consume fashion.

Disclaimer: This is revision 0 of this article - it is currently untested. Testing will naturally be done before this article is published.

The example module
------------------
For the sake of this exercise, we create a module called `example`, and we start by creating the overall layout of the module. The `cores` and `cpu` are invented categories.

    <module>
    |-- hiera.yaml                 #  For data using the site's categories
    |-- data                       #  Where the non-private data is by default
    |   |-- common.yaml            #  Module's common bindings not based on private data
    |   |-- . . .                  #  Module's additional bindings 
    |-- private                    #  The root for private data configuration
    |   |--hiera.yaml              #  The categories for the private data
    |   |--data                    #  The root of the private hiera-2 data
    |   |   |-- common.yaml        #  Common private bindings
    |   |-- cpu                    #  Bindings in the cpu category
    |   |   |-- x86.yaml
    |   |   |-- sparc.yaml
    |-- |-- cores                  # Bindings in the cores category
    |       |-- 2.yaml
    |       |-- 4.yaml
    |       |-- 8.yaml
    |-- lib
        |-- puppet
            |-- bindings
                |-- default.rb     # The 'example::default' bindings in ruby


A simple example::private bindings in Ruby
------------
We continue by creating a very simple ruby binding so we can test that the rest of the configuration
of our module works before we go with the private hiera-2 data.

In `<module>/lib/puppet/bindings/default.rb` we place the ruby bindings. Here is a simple start

    Puppet::Bindings.newbindings('example::default') do
      bind.name('test_key').to('cigar!')
    end

bindings_config.yaml
------------
Since we decided to place the private bindings in the module's bindings called example::default, we
do not have to modify the default bindings_config.yaml, it already aggregates all bindings
named `*::default` from all modules. The particular part of the `bindings_config.yaml` that does this
looks like this:

    layers: [
      { 'name' => 'site',
        'include' => ['confdir-hiera:/', 'confdir:/default?optional']  
      },
      { 'name' => 'modules',
        'include' => ['module-hiera:/*/', 'module:/*::default']
      },
    ]

Smoke test
----------
We can now test that all the configuration is down correctly by running this:

    puppet apply --parser future 'notice lookup(test_key)'
    
and we should get `'cigar!'` as output.

Binding directly in Ruby
----------
Before showing how to integrate private data in Hiera-2 let's start with doing the bindings
directly in ruby instead. This is after all what the result will be when read from Hiera-2.

We need access to the scope so we can base our binding decision on the provided facts.

    Puppet::Bindings.newbindings('example::default') do |scope|
      case scope['cores']
      when 1
        bind.name('test_key').to('cigar')
      when 2
        bind.name('test_key').to('cigars')
      when 4
        bind.name('test_key').to('cigar box')
      when 8
        bind.name('test_key').to('humidor')
      end
    end

It should be apparent how you would deal with additional private data bindings.

### Smoke test

    FACTER_cores=8 puppet apply --parser future -e 'notice lookup(test_key)'
    
Should output `'humidor'`.

Loading a Hiera-2 hierarchy
----------
You have probably already figured out that you do not really need to load Hiera-2 data, you
could just do the private bindings directly and conditionally in Ruby. You can keep all of the bindings in one and the same file. But maybe you want to be able to maintain and tweak the data between runs - the ruby bindings are sticky and you would have to restart the master to get a new set.

This part will be a bit more involved, but as you will see, the functionality we are developing can be broken out to a completely generic and reusable class. See the numbered comments after the code for details.

    # (0) Create bindings in ruby
    Puppet::Bindings.newbindings('example::default') do |scope|

        # (1) An receiver of issues
        #
        acceptor = Puppet::Pops::Validation::Acceptor.new()
        
        # (2) The hiera-2 bindings provider (loads the hiera.yaml and the data)
        #
        provider = Puppet::Pops::Binder::Hiera2::BindingsProvider.new(
          # (2.1) The name of the resulting bindings
          'example::default',
          
          # (2.2) The location of the private directory in this module
          File.join(scope.environment.module('example').path,'private'),
          
          # (2.3) Where issues go
          acceptor
          )
    
        # (3) Do the loading and get a bindings model back
        binding_model = provider.load_bindings(scope)
        
        # (4) Assert and report errors
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, 
          :message => 'example::private failed to load hiera-2 data, see detailed error(s)')
    
        # (5) See below
    
`(1)` - We load the hierarchy by using the Hiera-2 bindings provider. It uses an *issue acceptor* to
collect errors that occur while loading the configuration, so we need to create that first. We use it later to assert there were no errors, and if there were to report them to the user.

`(2)` We create the loader, and tell it what the resulting name of the loaded bindings
should be `(2.1)`, the location of the `hiera.yaml` we want to load `(2.2)`, and the acceptor `(1)`

In `(2.2)` we need to refer to the location of the private Hiera-2 data structure. Unfortunately
we have no reference to where it is on the file system. We know it is relative to where
the current ruby file is - so we could use that in an ugly relative path. But since the modules
and their locations are already known we can look it up in the environment and then simply
add the `'private'` directory in our module.

At `(3)` we perform the loading. This reads the `hiera.yaml`, and transforms all the data into
a *bindings model* that is returned.

At `(4)` we assert there were no errors and if there were they will be reported. We use the defaults
that will raise an error if there are errors, log deprecation warnings, and log warnings. We pass
a message that explains what the detailed errors are about.

At this point `(5)`, we have bindings that describe how to resolve request for lookups to values,
but we need to turn that into a set of *effective bindings* given what the values are in the 
scope - we only want these resulting bindings as we are going to serve them as bindings in the `common` category to the site-wide bindings.

        # (6) Create the binder
        binder = Puppet::Pops::Binder::Binder.new()
        
        # (7) Define the categories
        binder.define_categories(bindings_model.effective_categories)
        
        # (8) Define the layer(s)
        binder.define_layers(Puppet::Pops::Binder::BindingsFactory.layered_bindings(binding_model))
        
        # (9) Move the bindings to make them all common
        binder.injector_entries.collect do |unused, binding|
          # (9.1) model is a reference to the container of bindings being constructed
          # inside the code block given at (0)
          model.addBindings(binding)
        end
    # (10)
    end

We continue at `(6)` to create a binder. The binder is responsible for taking a set of individual
bindings, possibly conditional to a category, multi-bindings, etc. applying the *effective categories* to filter out the bindings that are either overridden, or that are not applicable. It ends up with a flat list of effective bindings.

In `(7)` we tell the binder that it should use the categories that we loaded from the private
Hiera-2 configuration (this works because we are not going to mix in data from any other sources - we are creating a single hierarchy and a single set of bindings). We call `bindings_model.effective_categories` to get the categories that were found in the private `hiera.yaml`.

In `(8)` we tell the binder that we only have a single layer consisting of the bindings we got
when loading the the private Hiera-2 bindings.

In `(9)` we want to move the resulting flat list of bindings into the bindings model
we are creating - i.e. why we started out doing at `(0)`.
We do this by cheating a bit (the binder has no public API
to get this list). We call `injector_entries` which is a hash mapping from an internal (opaque) key
to a binding. We simply want the binding, the opaque key is of no use to us here. We can now add this binding to the one we are constructing. We do that at `(9.1)` by adding it to the container of bindings that has been given to us by Puppet::Pops::Binder (at `(0)`) - this container is directly available via the attribute model. What we add in this container is in the `common` category.

At `(10)` we are done.

What we just did:

* Using Ruby Bindings
* We loaded a separate Hiera-2 hierarchy into a bindings model
* We resolved it into a flat list of effective bindings adapted to the current request
* We moved these bindings into a new container - now as common bindings

What happens after this point?
------------
When the `Puppet::Bindings.newbindings` return, the given block is registered under the given name
inside the Puppet binder system. Later, when the site's configuration is composed, it is picked up
from the internal registry since there is a rule to include `'module:/*::default'`, which will
result in the lookup of the entry `'example::default'` when our module is present in the system.

It will then evaluate the given block and compose the result with the result of all other included
bindings. If there are any conflicts they are reported.

Next steps in the evolution of the Puppet Bindings system
------------
The functionality described in this article is very useful to many module authors. It can easily be packaged up as a single method call and made available inside the block given to `Puppet::Bindings.newbindings`. The above could then look like this:


    Puppet::Bindings.newbindings('example::default') do |scope|
        load_from_hiera2('example', 'private')
    end
