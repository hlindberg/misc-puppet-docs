Structured Facts in RGen
===

User defines facts using RGen modeling. Since we place restrictions on what may
be expressed we prescribe how this should be done.

The user writes the model.rb and places it like so:


    {modulepath}
    └── {module}
        └── lib
            |── augeas
            │   └── lenses
            ├── facter
                └── model.rb


This model requires a base class (that we write) called something like `Facter::FacterModel`. This
model contains the base type `Fact`.

    module MyModule::Facts < Facter::FacterModel
    
      class IpAddresses < Fact
        contains_many_uni 'devices', NetDevice
      end
      
      class NetDevice < Fact
        has_attr 'name', String
        has_attr 'ip', String
        has_attr 'mtu', Integer
      end

    end
    
If the author of a fact want a more dynamic approach - say that users should be able to add their own keyed string data.

    module MyModule::Facts < Facter::FacterModel
    
      class IpAddresses < Fact
        contains_many_uni 'devices', NetDevice
      end
      
      class NetDevice < Fact
        has_attr 'name', String
        has_attr 'ip', String
        contains_many_uni 'data', CustomData
      end

      class CustomData
        has_attr 'name', String
        has_attr 'value', String
      end
    end

This is the simples way, we could naturally make the CustomData handle different data types, we could also make all Facts support this (all other facts inherit the ability).