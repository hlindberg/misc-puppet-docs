Puppet Doc
===
This describes a new Puppet Doc tools based on Geppetto.

Background
---
The current documentation tools are based on the Puppet runtime. This creates several problems:

* mixing concerns
  * processing doc text at runtime is a waste of cycles
  * makes logic more complex
* code needs to be loaded and evaluated
  * security issues (do not want to run someone else's code just to get the documentation)

Geppetto already has the ability to scan Ruby source and to get documentation from Puppet source.
It also has a simple Markdown parser and can produce HTML. This is used to provide documentation
hovers over various elements.

Desired Solution
---
* Can run headless as part of an automated build
* Can produce documentation in a format-agnostic way from which documentation can be rendered
  in different formats (text, markdown, html)
* Implementation can be used inside Geppetto for hovers as well as in other tool

Geppetto IDE Integration
---
In the Geppetto IDE it is of value to not only get the documentation hovers but to also navigate
to the full page of documentation the displayed snippet is a part of. This requires HTML rendering and navigating to the internal browser - alternatively, that the pages are served from an internal web server and made available also to an external browser.

Design
===

### Documentation Model

In the current implementation there is a small documentation model that can describe a handful
of document oriented types (paragraph, span, code, bulleted-list, bold, italic, etc.). There is
also a "target platform" model (.pptp) containing information about classes, defines, their parameters, types and their parameters, meta parameters and function.

The .pptp model contains unparsed text. The text is parsed into the small doc model on demand,
and is then rendered to HTML.

This is too simplistic for a real doc tool.

A new model should be created that contains the various elements in the Puppet ecosystem that
can be documented. The documentation is also in model form (similar to the current model).

The Documentation Model contains classes like these:

* Module
* (Host) Class
* Type (User defined, and plugin defined)
  * Parameter / Property
* Function
  * Signature
* Meta Parameters

### Markup Language

Currently, the supported markup language is a minimal markdown dialect. The rules are somewhat
imprecise and anything but the simplest markup is likely to produce surprises.

The current format does not allow the user to associate documentation with parameters, return
values, arguments etc. It is also not possible to describe that something is an example,
deprecation, or "also see" tags. Type information can also not be encoded.

It is therefore proposed that we define the Puppet Markup Language - a subset of markdown
with borrowed constructs from Yardoc.

Yardoc constructs:

* @example
* @param
* @deprecation
* @see
* @todo
* @api private | public
* @since version
* @return

The markup language needs to have syntax for linking to other documentable elements (i.e.
to other types, a particular parameter, etc). This to allow navigation/links to be generated
in the output.

It is also of value to be able to provide links to core concepts - say types in the Puppet
Language (to allow the reader to navigate to more information about the more complex types
such as Enum, Variant, etc). Other types of links in this category is to operators, expressions
etc. i.e. to handwritten documentation. 

### Markup extraction

The current markup extraction in Geppetto is somewhat different from the extraction in
the Puppet runtime. The Puppet runtime extracts by parsing the source using regular expressions
and it is often confused. It does however allow documentation to be associated with
more constructs than the Geppetto extractor/associator. Clear rules needs to be described.

A often repeated request is to add good support for documentation of parameters.

Currently, comments that immediately precede a documentable is considered to be documentation.
While this is ok for large blocks of comments, it typically creates garbage documentation when
the documentable element is a variable or some internal nested thing.
 

#### Parameters

Parameters can be handled like this:

    define(
      # the ip address
      $ip,
      
      # the name
      $name)
    {
    }
    
Or like this

    define(
      $ip,   # the ip address
      $name, # the name
      )
    {
    }

This also demonstrates the problem with comment association. What if...

    define(
      # a comment here
      $ip,   # the ip address
      # and a comment here
      $name, # the name
      )
    {
    }

Are comments left of right associative? If they are left associative, what do they
associate with, the first or the last construct on the line?

    define(
      $ip, $name, # the what?
      )

For variable assignment:

    $a = 10            # the 'a' is a ...
    $a = $b = $x = 10  # applies to which variable?

    # associates with a
    $a = 10
    
    # associates with what
    $a = $b = $x = 10  # applies to which variable?

    # associates with what ?
    $a = 
    # associates with what ?
    $b = 
    # associates with what ?
    $x = 10
    
### Ideas to Explore

Avoiding confusion over what is documentation and what is comment in ambiguous situations could
be made by requiring that such comments start a different way e.g. with `##` or `/**`.

For large block documentation this is not required, but it is allowed. When used the comment
may be above the element.

    /** This is documentation for foo
    */
    
    define foo() {} 

    ## This is documentation for foo
    
    define foo() {} 

Internal comments require the extra char. 

    ## Documentation for 'a'
    $a = 10 
    
    /** Documentation for 'a' */
    $a = 10
    
### Models and Ecore

The documentation model, and document (text) model are expressed using Ecore. The generated documentation results in an instance of these meta-models serialized to Json. 

We have one implementation of the model in Java, and one in Ruby (RGen). This makes it
easy for anyone to load and process the model in any language (general Json), and very easy
when coding in Ruby or Java (just load the model).

The generated documentation can either be shipped in one file, or multiple files. It can be built by
the module tool and included in the module.

Likewise, the Puppet Runtime also comes with a documentation model in JSon serialized score.

A command line tool can extract parts of the documentation and show the text. This tool replaces
the current puppet doc tool. The command line (ruby based) tool can only output in text form.

### Generators

#### Text Generator

The text generator is useful for command line use (give me the documentation for the type
foo::bar's parameter called 'options').

#### HTML Generator

The HTML generator produces a set of html pages in a directory. The HTML contains style information
but is otherwise void of any styling. All styling is done in CSS.

A default CSS is provided for basic rendering.
A default set of icons is provided.

The HTML generator also generates index pages.

More detailed requirements are needed regarding frames (index on the left of different kind),
ability to inline source code and/or navigate to source code (on the web to github, or internally
in Geppetto, in PE to source on disk, etc.). 

Additional features to consider:

* search (javascript function that searches in the index, or server backed (in Geppetto or
  deployable servlets / ruby code ?

#### Markdown Generator

The output is "plain" markdown (i.e. with all yardoc like tags processed into text). This
format is for those that want to include parts of the documentation in sites based on markdown,
or in other text processing flows.


Alternative Approach
===
Instead of using Geppetto - a similar implementation is written in Ruby. This requires:

* porting the ruby scanner to Ruby using a Ruby parser in Ruby
* a derived lexer that produces documentation tokens
* comment associator
* text extractor (from Puppet Markdown to Model)

The rest can work the same way.

