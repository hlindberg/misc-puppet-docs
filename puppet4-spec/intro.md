Puppet Language Specification
===

Terminology
---
<dl>
  <dt>Puppet Program</dt>
  <dd>A Program written in the Puppet Language</dd>

  <dt>Program</dt>
  <dd>A Program written in the Puppet Language unless text refers to some other language
      like Ruby Program, Java Program etc.</dd>
<dl>

Grammar Notation
---
Grammars (lexical and syntactic) are written in Extended Backus Naur Form (EBNF) with the
following syntax and semantics:

| syntax | meaning
|------  | -------
| 'c'    | the terminal character c
| '\r'   | the terminal ascii character CR
| '\n'   | the terminal ascii character NL
| '\t'   | the terminal ascii character TAB
| '\\'   | the terminal ascii character BACKSLASH
| rule:  | a rule name, must be written with at least one lower case character
| TOKEN: | a terminal token rule
| ( )    | groups elements
| ?      | the preceding element occurs zero or one time
| *      | the preceding element occurs zero or many times
| +      | the preceding element occurs one or many times
| &#124; | or
| /re/   | a regular expression as defined by Ruby 2.0
| ;      | rule end

### Examples
```
Hello: 'h' 'e' 'l' 'l' 'o' ;
Hi: 'h' 'i' ;
NAME: /[A-Za-z]+/ ;
Greeting: (Hello | Hi ) NAME '!'?;
```