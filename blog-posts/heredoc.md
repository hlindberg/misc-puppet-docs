Heredoc is here! Starting with Puppet 3.5.0 with --parser future turned on you can now
use Puppet Heredoc; basically a way to write strings of text without having to escape/quote special
characters. The primary motivation for adding heredoc support to the Puppet Programming Language
is to help avoiding the problem known as "backslash hell", where every backslash character in a
string may require, two, four or more backslashes to pass an actual backslash through multiple layers
of string special character interpretation.

Before talking about the features of Puppet Heredoc, lets look at an example:

     $a = @(END)
     This is the text that gets assigned to $a.
     And this too.
     END

As you probably already figured out, the `@()` is the heredoc start tag, where you get to
define what the end tag is; a text string that marks where the verbatim sequence of text on the lines
following the start tag ends. In the example above, the end tags is `END`. (Obviously you have
to select an end tag that does not appear as a separate line inside the actual text).

This blog post is a brief introduction of the Puppet Heredoc features, the full specification
is found in the [Puppet Heredoc ARM-4 text][1].

[1]:https://github.com/puppetlabs/armatures/blob/master/arm-4.heredoc/heredoc.md

### Trying out the examples

If you want to try out the examples, you need Puppet 3.5.0 and then turn on --parser future.

### Controlling the Left Margin

A problem with Heredoc is how to deal with text that appears in indented text, but you
do not want the indentation in the resulting string.

    if $something {
      $a = @(END)
      Text here is indented 2 spaces.
      END
    }
    
Puppet Heredoc solves this by allowing you to define where the left margin is by using
a pipe `|` character on the end-tag line at the position where the first character on each line
should be. To fix the example above, we then write:

    if $something {
      $a = @(END)
      Text here is indented 2 spaces.
      | END
    }

### Controlling trailing new-line

Another problem with heredoc text is how to deal with the line ending of the last line
of text (and any trailing whitespace on that line). With Puppet Heredoc you can easily strip
out trailing space and the newline by using a `-` before the end tag. (You can combine the - with | by placing the - after the pipe).

Here is the same example again, now without trailing new-line in the result:

    if $something {
      $a = @(END)
      Text here is indented 2 spaces.
      |- END
    }

### Interpolating variables

The default mode of Puppet Heredoc is to not interpolate variables (e.g. having `$a` in the
heredoc text does not expand to the value of the variable `$a`). If you need this, it is possible
to turn on interpolation by double quoting the specification of the end tag.

    $a = world
    notice @("END")
    The $a is an awesome place
    |- END

Will output "The world is an awesome place".

Naturally, since there also needs to be a way to enter a `$`, escaping is turned on for `$` and for `\`. Thus when using interpolation, a `\` must be entered as `\\`, and a `$` as `\$`.

You can use both styles of interpolation; either just `$a`, or `${a}`. The same rules for interpolation of expression as for double quoted strings apply.

### Controlling Special Character Escapes

By default, all character escapes are turned off (when using interpolation escapes for \ and $ are turned on). Puppet Heredoc also allows you to control escapes in more detail. The possible escapes are t, s, r, n, u, L, and $, and you can control these individually by specifying them in the heredoc start tag like this:

    $a = @(END/tL)
      This text has a tab\t and joins this line \L
      with this line.
      |-END

Most of the escapes should be familiar, except the `L` escape which makes it possible to escape
the end of line thus effectively joining a line with the next. The charters may appear in any order
in the spec. Using one (or more) escapes also always turn on escaping of `\`.

### Specifying the Syntax

The Puppet Heredoc start tag allows specification of the syntax of the contained text. This is done by following the end tag name with ':', and the syntax/language specification as a mime specification string following the ':'. Here is an example:

    $a = @(END:json)
    ["a"]
    - END 

The syntax/language tag serves dual purpose; it is an indicator to tools (such as Geppetto) how the tool should perform things like syntax highlighting or syntax checking, and it enables the Puppet Parser to perform syntax checking if there is a plugin that checks the given syntax. 

In Puppet 3.5.0, there is a syntax checker for Json, and consequently, if you were to enter the
following example, you will see it report the Json syntax error.

    $a = @(END:json)
    ['a']
    - END 

You will get the following error:

    Error: Invalid produced text having syntax: 'json'. JSON syntax checker: Cannot parse invalid JSON string. "unexpected token in array at ''a']'!"

New syntax checkers can be written in Ruby, and distributed as a Puppet Module. (This will be the topic of a future blog post).

### Summary

This blog post is an introduction to Puppet Heredoc. There are some additional features that are documented in the full ARM text, such as how to use multiple heredocs on the same line, the precise
semantics of special character escapes and margin control, the details about what is permissible as
an end-tag etc.

What better then to end with some poetry...

    notice @(Verse 8 of The Raven)
      Then this ebony bird beguiling my sad fancy into smiling,
      By the grave and stern decorum of the countenance it wore,
      `Though thy crest be shorn and shaven, thou,' I said, `art sure no craven.
      Ghastly grim and ancient raven wandering from the nightly shore -
      Tell me what thy lordly name is on the Night's Plutonian shore!'
      Quoth the raven, `Nevermore.'
      | Verse 8 of The Raven
