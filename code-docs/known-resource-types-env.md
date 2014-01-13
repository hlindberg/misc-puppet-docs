KRT and Environment
===
Known Resource Types and environments and the set of watched files are used in very complicated
patterns in the Puppet Runtime. This is an attempt of describing them and untangling the
behavior.

### $known_resource_types

A global variable that refers to an instance of Puppet::Resource::TypeCollection. The idea
is that this is a reference to "the" set of known types for the "current environment".

The variable is only referenced from within Environment and is reset to nil by the Parser::Compiler
at the start of a new compilation. The rest of the references are from tests (and are thus irrelevant).

It seems like $known_resource_types is not needed at all.

### The Environment @known_resource_types

This is the real place where the set of known resource types are kept. All logic that
wants to know the KRT asks for it by calling known_resource_types on the Environment.

This method jumps through hoops...

    $known_resource_types = nil if $known_resource_types && $known_resource_types.environment != self

This resets the global variable if it does not refer to the known resource types of this
environment. Essentially we switched "current environment" by asking for an environment's
set of known types.

This then continues with:

    $known_resource_types ||=
      if @known_resource_types.nil? or @known_resource_types.require_reparse?
        @known_resource_types = Puppet::Resource::TypeCollection.new(self)
        @known_resource_types.import_ast(perform_initial_import, '')
        @known_resource_types
      else
        @known_resource_types
      end

That is, if `$known_resource_types` is already a reference to this environment's KRT nothing
happens. Otherwise; if there is no KRT, or if the known set `require_reparse?`, a new KRT is created, and it is told to perform an initial import. Otherwise; it is assumed that the cached KRT should
be used.

### The proposed change in PUP-1322

First, the reset is different:

    $known_resource_types = nil if 
       $known_resource_types
    &&
       (  $known_resource_types.environment != self 
       || !@known_resource_types_being_imported && $known_resource_types.stale?
       )

i.e. 
* reset if not referring to this environment's KRT
* reset (if referring to this environment's KRT) the KRT is stale, but not if performing initial 
  import. (or in other words "check if stale if not doing initial import"
  
The next step is now:

    $known_resource_types ||=
      if @known_resource_types.nil? or @known_resource_types.require_reparse?
        # set the global variable $known_resource_types immediately as it will be queried
        # resursively from the parser which would set it anyway, just executing more code in vain
        @known_resource_types = $known_resource_types = Puppet::Resource::TypeCollection.new(self)
         # avoid an infinite recursion (called from the parser) if Puppet[:filetimeout] is set to -1 and
        # $known_resource_types.stale? returns always true; let's set a flag that we're importing
        # so if this method is called recursively we'll skip testing the stale status
        begin
          @known_resource_types_being_imported = true
          @known_resource_types.import_ast(perform_initial_import, '')
        ensure
          @known_resource_types_being_imported = false
        end
        @known_resource_types
      else
        @known_resource_types

this translates to

    if $known_resource_types.nil?
      if @known_resource_types.nil? || @known_resource_types.require_reparse?
        $known_resource_types = @known_resource_types = Puppet...TypeCollection.new(self)
        begin
          @known_resource_types_being_imported = true
          @known_resource_types.import_ast(perform_initial_import, '')
        ensure
          @known_resource_types_being_imported = false
        end
      else
        $known_resource_types = @known_resource_types
      end        
    end
    
The require_reparse? is "parse failed" || stale?
