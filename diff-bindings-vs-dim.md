Puppet Bindings Parts specific to Data in Modules
===

The parts that are specific to data in modules are all located under puppet/pops/binder (and corresponding unit test location).

Hiera 2
---
* ./hiera2.rb (10 LOC)
* ./hiera2 - contains the implementation of hiera2 (828 LOC)
* Scheme handlers specific to hiera 2
  * ./scheme_handler/confdir_hiera (67 LOC)
  * ./scheme_handler/module_hiera (92 LOC)
  
  IMPL LOC = 10+828+67+92 = 997
  
* spec/unit/pops/binder/hiera2 (456 LOC)
* spec/fixtures/unit/pops/binder/hiera2 (391 LOC)
  
Removing hiera-2 support = 10+828+67+92+456+391 =  1844 LINES

The above is a clean removal, needs removal of a few places where hiera2 wired into
the overall composition (basically just removing the hiera scheme handler references.

Lookup Function
---
The lookup function itself is not needed (all lookups are internal for injection purposes).
-279 LOC

997 + 279 = 1276

Hierarchical categories
---
They are mainly supported for the purpose of data bindings, but are useful for non data
to provide at least one base level (default), and a second higher level, as well as a system - do not override level.

Layers
---
Layers are needed to provide complete override of things at site level.

Plugins
---
One of the key features is to enable plugging in ruby code that is delivered in a module.
For tis, the bindings system still needs to be able to load from a module, just not hiera2.
(i.e. Ruby bindings - this is fine, it is after all extending puppet with ruby code).

(This could be used to define data :-)

Layers only
---
Switching to only using layers (no hierarchy/category), would enable removing more code, but is not just a clean remove (rewrites needed), the basic construction is still the same, i.e. loop over bindings, if higher level binding exist, lower level is ignored, if at same level conflict etc. it is just more cource grained.

The amount of code to remove is hard to count:

* BindingsFactory does not need when_in_category, when_in_categories (20-40 LOC?)
* Model does not need predicated bindings (20-40 LOC?)
* the overall config does not need to deal with checking category priority consistency (100 LOC)
* Simpler booting of injector (no need to calculate and set the categories, lines saved is mainly in
  tests (it is otherwise just set up in one place).
  
Operating in layers only works fine for plugins and internal compositions. (Google guide comparison, an injector is created on a list of "modules" (i.e named set of bindings). One set of modules can be overridden by another set of modules, the result must be consistent, this is the only hierarch). This has been enough even in demanding Java applications, we really do not need more inside the
runtime.


Advanced Producers
---
There are a couple of advanced producers that can create series, lookup other producers etc.
These can be put aside until actually needed. (They are also quite small). (200 LOC?)


Summary
---
Binder Impl (not counting type, unit tests) = 5700 LOC
- hiera2 Impl = 1300 LOC
5700 - 1300 = 4400
 
Impl LOC = 4400 for Binder (not counting test, fixures etc)
Removal of feature creep / fluff = 500-700 LOC? (guess, and that is quick to factor out).

Remains 3700 LOC. 35% reduction

Effort 2 days.

Removal of categories (very little performance impact), reduces some complexity. 5 days of work,
guessing 500 LOC in total? More difficult to put back. Suggest keeping while discussing approaches to data in modules. If hierarchies not needed / can be taken out permanently. Does little harm, and we learn what we actually want to use/keep/what is important as we increase the use of the injection functionality. (Right now, that is only used to support plugins for Templates and Heredoc).



