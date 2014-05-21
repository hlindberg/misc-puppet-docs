Loaders
===

System Loader
---
The SystemLoader is responsible for loading from the Puppet libdir.

EnvironmentLoader
---
Is responsible for loading from the environment root, and setting up lazy loaders for
everything on its module path.

It is parented by the SystemLoader.

Problem: There is nothing enumerating what is visible in the environment. If all modules, even
those there is no direct dependency on in the environment then it may find multiple instances.

Required Changes:

* the environment must have a list of modules that are visible to it directly.
* the module path must be able to hold multiple versions of the same module.

ModuleLoader
---
Is responsible for loading from one particular module. It does not expose its dependencies.
The code internal to one module will get this module's DepedencyLoader and it is parented by
the ModuleLoader for the module. Hence, code inside the module gets the correct, full view.

A module is currently always layer out on disk. Later a module may be a signed zip file.
Both these kinds of loaders are path based and they can share the information how to map
a name to a path relative to a root (a file system directory, or the root of the zip).

When the module loader is instantiated, a decision must be made with form of name to path resolver
it should use - based on the file system or a zip. This is the task of the ModuleLoaderConfigurator.

ModuleLoaderConfigurator
---
Is instantiated and given the module path from an environment. (The top level boot of the configuration of loaders).

The path is scanned. Each entry is a directory where modules can be found (a directory).
If an entry in one of these directories is in turn a directory, the name of that director
is the name of the module. If it instead is a zipped and signed module it is a .zip, .jar, or
a puppet specific .par file) - in that case it creates a technically different ModuleLoader (capable
of loading a zip).

LazyLoader
---
A lazy loader is a wrapper around a real loader - it replaces the loader when the first request
comes for which the loader may have content (a name in its name-space).

This is complicated if any module may contain top level named elements. If so, each module
must be queried for everything that is not resolved by a parent (high precedented) loader.

An alternative is for a module to provide an index of what it contains. If so, then the lazy
later can obtain this index without having to fully scan every module for content.

(once a module is instantiated; something in it is used, then the lazy loader has played its role
and becomes a simple delegator).

It is costly to a) scan a module's content, and b) resolve its dependencies.

DependencyLoader
---
Is responsible for loading from a given list of loaders. Typically the modules and gems
a module depends on. The list of dependency loaders should typically be ModuleLoader instance
(and not DependencyLoader since that means that everything the other module sees is also
re-exported to everyone else.


Instantiators
---
At the bottom level of the loader hierarchy there are instantiators. An instantiator is
typically given a string content (puppet or ruby code), a source reference (for error reporting),
and a TypeName key representing what it is expected to produce.

This construct makes it possible to obtain the content from any source - instantiation is
only done in one place irrespective of if the source came from a file in the file system, a
file in a zip file, or from some other type of lookup.

There are currently three Instantiators:

* RubyFunctionInstantiator - handles the 4x function api
* RubyLegacyFunctionInstantiator - handles the 3x function api
* PuppetFunctionInstantiator - handles functions in puppet code



