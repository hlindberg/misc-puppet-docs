Templating with Embedded Puppet Programming - EPP

Next up in the long list of new features coming to the Puppet Programming Language i Puppet 3.5.0 is the support for EPP templates. EPP is to the Puppet Programming Language what ERB is to Ruby, and EPP supports the same template tags as ERB.

### EPP Syntax

| tag | description |
| --- | --- |
| `<%`  | Switches to puppet mode |
| `<%=` | Switches to puppet expression mode. (Left trimming is not possible) |
| `<%%` | Literal `<%` |
| `%%>` | Literal `%>` |
| `<%-` | Trim Left When the opening tag is `<%-` any whitespace preceding the tag, up to and including a new line is not included in the output. |
| `<%#` | Comment A comment not included in the output (up to the next `%>`, or right trimming `-%>`). Continues in text mode after having skipped the comment (observes right trimming semantics).
| `%>` | Ends puppet mode
| `-%>` | Ends puppet mode and trims any generated trailing whitespace |

In addition to these (ERB compatible) tags, the very first tag can specify a set of parameters that
can be given to the template when it is used, much like parameters can be declared in a `define`. This
is done by using this syntax:

    <%-( $x, $y, $z='this is a default value' )-%>

### EPP Functions

EPP template text is produced by the two epp functions:

* `epp(filename, optional_args_hash)` - for evaluating an `.epp` file
* `inline_epp(epp_text_string, optional_args_hash)` - for evaluating a string in EPP syntax

### Puppet ERB vs. EPP

Basically, existing `.erb` templates can be changed to `.epp` and references to variables
simply changed to use Puppet's `$var` notation instead of the Ruby instance variable
notation `@var`. The programming logic in general is different in the Puppet Programming Language, but it is expected that most templates are not complex enough to require Ruby (since Puppet now
supports iteration).

The main benefit of using EPP is that that the same syntax and semantics apply as elsewhere in
the Puppet manifests, and there is no risk of calling out to Ruby in unsafe ways.

The new functions are also different in that they operate on **one** file/string. If you want
to render multiple files into a single string, you can concatenate them using string interpolation,
or the `join()` function from standard lib.

### Visibility of Scoped Variables

A problem with Puppet ERB in general is that the template has full access to the invoking scope
which makes it very difficult to write reusable templates (the exact same set of variables
must be available in all scopes where the template is being used).
This also leads to poor separation of concern - a change to the
logic may affect templates that are in use, and templates may cause unintentional side effects.

In EPP the rules are therefore different than in ERB.

* Both `inline_epp()` and `epp()` always provide access to the global (i.e. top/node) scope 
  variables.
* `inline_epp()` provides access to the local scope variables unless an (optional) hash of variable 
  name/value entries is given in which case these are used **instead** of the local scope variables.
* If a template declares parameters that require a value to be set, these must be given in 
  the name/value hash
  
While these rules may seem complicated at first, they are quite natural to use in practice.
Think of an `.epp` file as a function that is called. Like all functions it has access to 
all global variables + the the values that are given to it when it is called (i.e. when `epp()` is
called). When calling a function, it is good to specify the parameters it accepts instead of just
blindly throwing it a set of variables - that way an error is raised instead of something just
not rendering as expected.

For `inline_epp()`, the typical use is to render something from the calling scope. In this case
nothing special needs to be declared (no parameter declaration, nor any passing of arguments). If
you however plan to later move the template to a file, and you are just using it inline while
trying things out then you want to both declare the parameters and call it with arguments even
if this initially means unnecessary typing. The end result is that an inline epp works the same
as a file based epp when argument are given to it.

### Examples

The examples makes use of [Puppet Heredoc][1] to specify the template text.

[1]:http://puppet-on-the-edge.blogspot.com/2014/03/heredoc-is-here.html

    $x = droid
    notice inline_epp(@(END))
    This is the <%= $x %> you are looking for!
    | END

Produces a notice of the string "This is the droid you are looking for!"
    
    $a = world
    notice inline_epp(@(END), {x => magic})
      <%-( $x )-%>
      <% Integer[1,3].each |$count| { %>
      hello epp <%= $x %> <%= $a %> <%= $count %>
      <%- } %>
      |- END

Produces the following output:

    Notice: Scope(Class[main]): 
    hello epp magic world 1
    hello epp magic world 2
    hello epp magic world 3

(In the example above `$a` resulted in `"world"` because all of the logic is in the global scope).

### EPP Template files

EPP template files must end with .epp, and they are placed in the same location as where you
place .erb templates for use with Puppet. For testing purposes you can specify the location
on the command line - below using the current directory:

    puppet apply --parser future -e 'notice app("foo.epp")' --templatedir .

(Obviously also placing the EPP source you want to test in the file `foo.epp`).

### Summary

Puppet Templates are available when using the `--parser future` feature switch with Puppet 3.5.0 - The functions `epp()`, and `inline_epp()` provides EPP templating capabilities using the Puppet Programming Language as opposed to the Ruby based ERB based already existing `template`, and `inline_template` functions.
