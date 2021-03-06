PuppetDoc and RDoc
===
Puppet RDoc is written for RDoc 1 and the implementation specializes classes that are no longer
present in later RDoc. Specifically, the old HTML generator is replaced by a generator called
Darkfish.

PuppetDoc makes use of a special generator in order to fix/trick Rdoc:

* RDoc::Markup is monkey patched to allow lower case class cross ref hyperlinking
* Loads its own templates based on a template engine that is no longer present in RDoc > 1)
* Blocks generation of list of methods (== Puppet Defines)
* Overrides generate_html to also generate output for nodes and plugins (which are otherwise
  missing from the output.
* Builds all indices (files, modules, classes, nodes, resources and plugins, etc.)
* Generates class list

The HTMLPuppetClass, HTMLPuppetModule, generators are derived from (no longer existing) HtmlClass.

The HTMLPuppetNode, and HTMLPuppetPlugin are derived from RDoc::ContextUser (which no longer exists).

The HTMLPuppetResource is a handcrafted specialization of RDoc::Markup.

The class HtmlGeneratorInOne is also specialized to write all output into "one", this class no longer exists.

The current generator is 1000 LOC, the template is 1100 LOC, code objects 280, parser 500.
Total LOC = 1000+1100+280+500 = 2880 LOC, of these roughly 2200 are special to Rdoc1.

## Options

* Modify code objects to produce objects that Darkfish can/will render in a meaningful way without
  modifying or deriving a new generator.
* Derive from Darkfish
* Write new Generator
* Port Rdoc1 classes

Modify Code Object Model
===
Instead of representing Plugins and Nodes a special way, these could instead be turned into
some other type of code object that Darkfish renders in a meaningful way.

Tasks:

* Figure out how to represent the elements that are not generated by vanilla darkish.
* Possibly style the output

To do this, either the parser (makes call to CodeObjects), CallObjects, or possibly both
needs to be changed.

Plugin and Fact are derived from Context (which still exists), but may (?) not render correctly

Nodes are added to a container (in CodeObjects) with add_node, which creates and instance of PuppetNode (derived from PuppetClass), in a PuppetModule.

Derive from Darkfish
===
The Darkfish template is implemented using ERB instead of the earlier RDoc specific template
engine (?).

Tasks:

* rewrite the puppet templates using ERB (1100 LOC) and adapt to Darkfish
* The generator is different, and apron 50% of the generator's 1000 LOC needs to be rewritten

The code objects and generator are intertwined with RDoc 1 logic. This is not an easy task as
the implementation is mostly not documented, and consists of a mix of "magic one-liners" and
heavy lifting (shuffling data around).


Write New Generator
===
Write new generator based on ERB.

* Rewrite the 1100 LOC template into ERB
* Replace the missing code object's superclasses with available alternatives
* Write the RDOC > 1 generator to output HTML

This moves the complexity to writing the infrastructure of the generator for HTML, and keeps the old
complex and mostly undocumented code.
