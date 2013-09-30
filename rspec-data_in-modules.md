How to use rspec & data in modules
===
(w.i.p)

Testing with/without binder active
---
Currently (while the binder is experimental), the setting Puppet[:binder] turns the binder on
or off with a boolean value. Simply set it to true before creating a scope or a compiler
to activate the bindings system. (It is off by defaults).

    Puppet[:binder] = true
    scope.compiler.is_binder_active?  # => true

Turning on parser future has the same effect.

Defining the content of binder_config.yaml
---
### Setting :binder_config

The easiest way to provide the data to the binder is to use the puppet setting that defines
the name of the file to load (full path to the file containing the config):

    Puppet[:binder_config] = '<path to a yaml file with the config>'

### Mock the confdir used by the binder

Mock the confdir and point to a directory that serves as the confdir. This will make
the system use binder_config.yaml at the given location.

    Puppet::Pops::Binder::Config::BinderConfig.any_instance.stubs(:confdir).returns(my_fixture("/ok/"))

### Mock a default method

Mock one the methods shown below in Puppet::Pops::Binder::Config::BinderConfig and either
have a confdir that is null or a confdir that contains no binder_config.yaml file.

Here are examples producing the various data elements:

    binder_config = Puppet::Pops::Binder::Config::BinderConfig
    
    # If other layering than default is wanted, use something like this
    binder_config.any_instance.stubs(:default_layers).returns( 
      [
        { 'name' => 'site',    'include' => ['confdir-hiera:/', 'confdir:/default?optional']  },
        { 'name' => 'modules', 'include' => ['module-hiera:/*/', 'module:/*::default'] },
      ]
    )

    # If other categories are wanted than the default, use something like this
    binder_config.any_instance.stubs(:default_categories).returns(
      [
        ['node',            "${fqdn}"],
        ['operatingsystem', "${operatingsystem}"],
        ['osfamily',        "${osfamily}"],
        ['environment',     "${environment}"],
        ['common',          "true"]
      ]
    )    
    
    # empty by default, define a scheme like this
    binder_config.any_instance.stubs(:default_scheme_extensions).returns(
      { 'myservice' => 'Puppetx::MyModule::MyService' }
    )

    # empty hash by default, define a hiera2 backend like this
    binder_config.any_instance.stubs(:default_hiera_backends_extensions).returns(
      { 'mybackend' => 'Puppetx::MyModule::MyHiera2Backend' }
    )

Defining Data Bindings
---
You can provide data bindings programmatically in your tests by using `Puppet::Bindings`

The easiest is to use the ability to define and register a set of bindings under a name
directly like this:

    Puppet::Bindings.newbindings('name') do
      bind('mykey').to('myvalue')
      # bind ...
    end

The name that is used is available to be used in the bindings configuration. By default,
anything registered with a qualified name of `*::default` will be loaded.

You may want to use a layer for tests, that loads `*::test`, where '*' should be the name of the module you are testing / providing test data for.

    Puppet::Bindings.newbindings('apache::test') do
      bind('apache::port').to(80)
      # bind ...
    end

If you need access to the scope while doing the bindings, use this:

    Puppet::Bindings.newbindings('apache::test') do |scope|
      bind('apache::port').to(80)
      # bind ...
    end

To create conditional bindings:

    Puppet::Bindings.newbindings('apache::test') do
      when_in_category('node', 'kermit.example.com') do
        bind('apache::port').to(80)
        # bind ...
      end
      # bind ...
    end

Note that the names of the bindings (e.g. 'apache::test') is just the name of the set of bindings being defined. This name is only used for loading the set. (e.g. you can bind the value of 'apache::port' in a set called 'foo::bar', and this will set 'apache::port' as long as 'foo::bar' is loaded.

Naturally, these calls must take place before the compiler creates the injector. Once the injector has been created, it can not be modified. It is also possible to assign a new injector (manually created) to the compiler for advanced testing. 

The defined test bindings are included by doing this:

    binder_config.any_instance.stubs(:default_layers).returns( 
      [
        { 'name' => 'site',    'include' => ['confdir-hiera:/', 'confdir:/default?optional']  },
        { 'name' => 'test',    'include' => 'module:/*::test' },
        { 'name' => 'modules', 'include' => ['module-hiera:/*/', 'module:/*::default'] },
      ]
    )

Or, if completely controlling all the data, simply:

    binder_config.any_instance.stubs(:default_layers).returns( 
      [ { 'name' => 'test',  'include' => 'module:/*::test' }]
    )

### Other options

There are many other options for loading data bindings. A hiera-2 hierarchy could be
loaded from yaml files, A regular ruby file required that performs the calls shown above
above (calling `newbindings`), or manually built. 

At the moment this requires a bit of digging in the source code documentation and
looking at spec tests. Please supply use cases where you need more advanced configuration as this
gives us the opportunity to update the documentation.

Testing Data Bindings
---
The compiler loads all bindings and constructs an injector based on the binder_config, and the available data from all contributors listed in the spec.

When your test has access to a scope, the compiler is accessed as

    compiler = scope.compiler

The injector is accessed as:

    injector = compiler.injector
    
You can now perform lookups:

    # with name only
    injector.lookup(scope, 'name')
    
    # with type and name
    injector.lookup(scope, type, 'name')
    
    # you can pass a block
    injector.lookup(scope, 'name') {|result| . . . }
    
Note that the injector lookup returns nil when there is no value.

Type is constructed like this:

    types = Puppet::Pops::Types::TypeFactory
    
    string_type = types.string()
    integer_type = types.integer()
    hash_of_string_string_type = types.hash(types, string(), types.string())
    # etc...
    
Using type provides type assertion of the lookup.
    