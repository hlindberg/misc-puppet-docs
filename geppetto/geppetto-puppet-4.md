Geppetto for Puppet 3.5 / 3.6 and 4.0
===
There are many changes in Puppet 3.5, upcoming 3.6 and ultimately in 4.0
This document describes the various changes in terms of the release numbers where
just the release number means the regular parser, and the future parser when prefixed with F.

3.5
---
### Directory site.pp

In Puppet 3.5 it is possible to have a directory function as a site.pp. The files in this
directory are evaluated in file name order as if all of the files were concatenated.

Geppetto cannot handle these correctly when:

* they are outside of the known path
* the order in which Geppetto processes them is not the same as the runtime and validation
  may result in both false negatives and positives. (unsure - may work, need to come up
  with test that can trigger this)

F 3.5 
---
### Heredoc

Heredoc support as described in the ARM-4 Puppet Heredoc has been added to the future parser.
This means that:

* The Geppetto lexer should handle the Heredoc syntax
* Geppetto can syntax color the Heredoc text if a syntax is specified and the syntax is known
  (e.g. :epp, :json, :yaml)
* Geppetto can validate the syntax if the syntax is known


### Puppet Templates

The support for templates means that Geppetto:

* should be able to handle .epp files (lex, parse, validate)
* should be able to provide language features inside of an .epp file (i.e. code completion,
  navigation, etc.)
* should be able to provide language features inside of an heredoc with :epp syntax.

ARM-4 is not quite up to date, EPP parameters are delimited with pipes like for lambdas:
`| <params> |`, not  `( params )` as the ARM text (currently) says.


### Unparenthesized Function Call

Function calls without parentheses are only allowed for the following built in functions,
and not for "statement functions" in general.

The following snippet from Puppet shows the allowed statement functions:

    STATEMENT_CALLS = { 
      'require' => true, 
      'realize' => true, 
      'include' => true,
      'contain' => true,

      'debug'   => true,
      'info'    => true,
      'notice'  => true,
      'warning' => true,
      'error'   => true,

      'fail'    => true,
    }

Geppetto should treat other unparenthesized calls as being in error, and offer a quick fix
to refactor them into parenthesized calls.

### If and Case are now R-values

The following are allowed:

    $a = if true { 10 } else { 20 }
    $b = case true {
         true : { 1 }
         }

         