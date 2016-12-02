Puppet Parser API
===

The Puppet 4.x parser has now been stable for quite some time, and we feel it is the right time to make the APIs to lexing, parsing, and evaluation available. Not that they were unavailable earlier, but these APIs have not been documented or officially been communicated as ok to use.

As of Puppet 4.9.0 you will see us tightening up the APIs as we may have marked too many things as being public, or forgot to mark them at all. As we start to work with "Puppet Language" as a library in more earnest we are also sure that we will find things that could be improved.

When working with the Puppet Language at the level provided by these APIs it is important to understand the overall process
of what is often referred to as "parsing". In brief this is what happens:

* The string containing the source code is given directly to the **Parser**, or is read from a file.
  For example: `"1 + 2 * 3"`.
* The **Lexer** turns the stream of characters in the input string into a sequence of **Token** values (analogous to
  how we when reading a text group letters into words). For example `[INTEGER, PLUS, INTEGER, MUL, INTEGER]`
* The Parser builds an Abstract Syntax Tree (**AST**) based on the stream of tokens.
  It is directed by a **Grammar** that defines how expressions are formed in the puppet language.
  For example:

```
  ArithmeticExpression(
    operator   => '+',
    left_expr  => LiteralInteger(1),
    right_expr => ArithmeticExpression(
      operator   => '*',
      left_expr  => LiteralInteger(2),
      right_expr => LiteralInteger(3)
    )
  )
```

* The AST then undergoes **Validation** to check semantic correctness of the AST.
* The result can then be **Evaluated**. The example evaluates to 1 + (2 * 3) = 7.

When do I use the lexer, and when do I use the parser?
---

Which API should you be using given that you need to write code that understands text in the Puppet Language?
In almost all cases should you use the Parser's API as that gives you a syntax checked AST which is much easier to use than
trying to make sense of the tokens coming out of the lexer. You would for instance have to apply arithmetic precedence for the different operators as well as deal with far more complex translations of the tokens into AST (for example heredoc, calls to
functions without parentheses around arguments, significant whitespace, and the various forms that
resource expressions can be formed).

If however you are writing something where you do not need to comprehend the syntax of the source, like supporting light syntax coloring, or searching for simple language constructs, or you want to try to give a user more feedback than what the parser does (if the parser says 'syntax error', you may still have a valid set of tokens that could be used for some brilliant analysis that you have come up with.

Note though, that lexical/textual information is available in the AST, so the right choice is almost always
to use the Parser over the lexer.

Lexing
---
It is possible to get a stream of tokens from the Puppet Lexer. This stream of tokens is what the parser gets as input given Puppet Language source text. There are basically two ways to interact with the lexer:

* Get all tokens at once (raises error if there are lexical errors)
* Get tokens one by one (raises error when getting a token if there is a lexical error next)

Each token is delivered as an `Array` of two elements; a symbol (for example `:VARIABLE`), and a `TokenValue` object.
The token value is an instance of `Puppet::Pops::Parser::LexerSupport::TokenValue`.
At the end of input, the lexer always returns an array `[false, false]`. Trying to get additional tokens after that raises an error.

Here is a simple example of how to use the lexer

    require 'puppet'

    # Create an instance of lexer. It can be used for lexing one input at a time
    lexer = Puppet::Pops::Parser::Lexer2.new

    # Give it the source to lex
    lexer.lex_string('$a = 10', 'unknown file')

    # Get all tokens as an array, and drop the [false, false] 'end of input' token
    tokens = lexer.fullscan[0..-2]

    # Looking at the three resulting token symbols
    puts tokens[0][0].inspect  # => :VARIABLE
    puts tokens[1][0].inspect  # => :EQUALS
    puts tokens[2][0].inspect  # => :NUMBER

    # Looking at the three resulting values
    puts tokens[0][1][:value]  # => "a" (the name of the variable without the "$")
    puts tokens[1][1][:value]  # => "=" (the operator)
    puts tokens[2][1][:value]  # => "10" (the number as given in string form)


Additional information available in the `TokenValue` accessed as `token[<symbol>]`:

| symbol     | value |
| ---        | ---   |
| `:value`   | the lexed part of the source consumed by this token as a `String`
| `:file`    | the name of the lexed file, or "" (empty string) if lexer was not given a file name
| `:line`    | the line number of the token's source text's first character (first line is 1)
| `:pos`     | the position of the token's source text's first character on the line
| `:length`  | the length of the token's source text in a **locator specific** units
| `:locator` | an object from which additional information can be obtained
| `:offset`  | the offset from the beginning of the source text in **locator specific** units

Note that the `length` and `offset` are measured in units that are determined by the `locator`, and they should only
be used as input to the `locator`'s methods. The reasons for this is that the lexer may work on a byte by byte level if that is more efficient than operating on multibyte UTF-8 characters. (To date all Ruby MRI implementations have been faster when doing byte operations).
We designed this API so that use of the lexer API is free of this implementation concern. In the future, the Ruby multi byte string operations may be faster, and we may then switch the implementation. We can do so without affecting the API.

The `locator` has a simple API:

| method                                | produces |
| ---                                   | ---      |
| ´string´                                | the same as the token's `value`
| ´file´                                  | the same as the token's `file`
| ´pos_on_line(offset)´                   | the same as token's `pos` (first char on a line is 1)
| ´line_for_offset(offset)´               | the same as token's `line`
| ´offset_on_line(offset)´                | 0 positioned version of `pos_on_line` (first char on a line is 0)
| ´char_offset(offset)´                   | the string character index to first char from beginning of input
| ´char_length(start_offset, end_offset)´ | the number of characters between (inclusive) of start and end offset
| ´extract_text(offset, length)´          | the input source text from locator offset of locator length
| ´line_index´                            | array of line start offsets, starting with 0 for the first line

The typical operation is to extract the source text (for tokens that is not that exciting as the string value has already been extracted and is available as the **value**. Later you will see that the parser's AST objects also supports this, and you can then extract the source text of a series of tokens that make up that AST object.

The other operations are useful for performing textual operations on the source code. The lexer skips all comments and whitespace - no tokens are generated for those - they are simply not part of the output. You can however use the lexer and the locator's information to obtain the source text that is between tokens. All tokens actually have the same locator, and this locator is also available from the lexer itself.

Example - getting the source text between tokens:

    lexer = Puppet::Pops::Parser::Lexer2.new
    lexer.string = '$a = /* hello comment */ 10'
    tokens = lexer.fullscan[0..-2]

    t1 = tokens[1][1]
    t2 = tokens[2][1]
    start = t1[:offset] + t1[:length]
    between = lexer.locator.extract_text(start, t2[:offset] - start)
    puts between  # => " /* hello comment */ "

In general the lexer methods are much faster than the general string operations required to find things like text between tokens, positions, and offsets, and are well worth the extra code required since many puppet manifests are quite long.

Scanning token by token
---

Scanning token by token is done by calling the lexer's `scan` method with a lambda that receives the next token.
The scan will always scan from the start until the given lambda breaks, or reaching end of input. Note that the puppet language
is not context free - it is not possible to start lexing source text from any given position in the source. It must always start
from the very beginning.

    lexer.scan do |t|
      break if t == [false, false]
      # do stuff
    end

Using the "by token" may be faster than performing a full scan as the operation does not produce all tokens in an array.
As you can see the style used is that the lexer "pushes" the tokens onto a consumer (such as a parser). There is no official API for "pulling" token by token - for that use the fullscan and the operate on the returned array.

Lexing Multiple Inputs
---

The lexer maintains its current lexing state until a call is made to `clear`. If you have multiple inputs to lex it is faster to reuse the same lexer and calling `clear` between each input.

Lexing a String or a File
---

The lexer has the method `lex_string` which accepts the source text and the name of a file. The name of the file is used as the file source in the locator and in error messages. That file is not opened or read.

The method `lex_file` accepts a file name. The file is read, multibyte BOM (byte order marks) are processed, and the resulting source text is turned into UTF-8 before lexing. The given name is the name available in the locator.

Call one of these methods after a `new` or after a `clear` to setup the lexer for lexing. Then call the `fullscan`, or the `scan` to do the lexing.

Token Symbols
---
The language set of token symbols is defined in the source of `Lexer2`. They are considered API. From Puppet 4.9.0 and forward we are also going to treat the sequence of tokens generated to be API. Before Puppet 4.9.0 we introduced new tokens to differentiate between certain lexical constructs. Such changes will from Puppet 4.9.0 only be made on major version boundaries.

Here is the (slightly edited) definitions of the tokens from `Lexer2`. This shows the name of the token (in the lexer),
the symbolic value (as present in the tokens returned by the lexer), the text the token matches, and that tokens length (for fixed length tokens).

    TOKEN_LBRACK       = [:LBRACK,       '[',   1]
    TOKEN_LISTSTART    = [:LISTSTART,    '[',   1]
    TOKEN_RBRACK       = [:RBRACK,       ']',   1]
    TOKEN_LBRACE       = [:LBRACE,       '{',   1]
    TOKEN_RBRACE       = [:RBRACE,       '}',   1]
    TOKEN_SELBRACE     = [:SELBRACE,     '{',   1]
    TOKEN_LPAREN       = [:LPAREN,       '(',   1]
    TOKEN_WSLPAREN     = [:WSLPAREN,     '(',   1]
    TOKEN_RPAREN       = [:RPAREN,       ')',   1]

    TOKEN_EQUALS       = [:EQUALS,       '=',   1]
    TOKEN_APPENDS      = [:APPENDS,      '+=',  2]
    TOKEN_DELETES      = [:DELETES,      '-=',  2]

    TOKEN_ISEQUAL      = [:ISEQUAL,      '==',  2]
    TOKEN_NOTEQUAL     = [:NOTEQUAL,     '!=',  2]
    TOKEN_MATCH        = [:MATCH,        '=~',  2]
    TOKEN_NOMATCH      = [:NOMATCH,      '!~',  2]
    TOKEN_GREATEREQUAL = [:GREATEREQUAL, '>=',  2]
    TOKEN_GREATERTHAN  = [:GREATERTHAN,  '>',   1]
    TOKEN_LESSEQUAL    = [:LESSEQUAL,    '<=',  2]
    TOKEN_LESSTHAN     = [:LESSTHAN,     '<',   1]

    TOKEN_FARROW       = [:FARROW,       '=>',  2]
    TOKEN_PARROW       = [:PARROW,       '+>',  2]

    TOKEN_LSHIFT       = [:LSHIFT,       '<<',  2]
    TOKEN_LLCOLLECT    = [:LLCOLLECT,    '<<|', 3]
    TOKEN_LCOLLECT     = [:LCOLLECT,     '<|',  2]

    TOKEN_RSHIFT       = [:RSHIFT,       '>>',  2]
    TOKEN_RRCOLLECT    = [:RRCOLLECT,    '|>>', 3]
    TOKEN_RCOLLECT     = [:RCOLLECT,     '|>',  2]

    TOKEN_PLUS         = [:PLUS,         '+',   1]
    TOKEN_MINUS        = [:MINUS,        '-',   1]
    TOKEN_DIV          = [:DIV,          '/',   1]
    TOKEN_TIMES        = [:TIMES,        '*',   1]
    TOKEN_MODULO       = [:MODULO,       '%',   1]

    TOKEN_NOT          = [:NOT,          '!',   1]
    TOKEN_DOT          = [:DOT,          '.',   1]
    TOKEN_PIPE         = [:PIPE,         '|',   1]
    TOKEN_AT           = [:AT ,          '@',   1]
    TOKEN_ATAT         = [:ATAT ,        '@@',  2]
    TOKEN_COLON        = [:COLON,        ':',   1]
    TOKEN_COMMA        = [:COMMA,        ',',   1]
    TOKEN_SEMIC        = [:SEMIC,        ';',   1]
    TOKEN_QMARK        = [:QMARK,        '?',   1]
    TOKEN_TILDE        = [:TILDE,        '~',   1] # lexed but not an operator in Puppet

    TOKEN_IN_EDGE      = [:IN_EDGE,      '->',  2]
    TOKEN_IN_EDGE_SUB  = [:IN_EDGE_SUB,  '~>',  2]
    TOKEN_OUT_EDGE     = [:OUT_EDGE,     '<-',  2]
    TOKEN_OUT_EDGE_SUB = [:OUT_EDGE_SUB, '<~',  2]

    # Tokens that are always unique to what has been lexed (value and length will vary)
    TOKEN_STRING         =  [:STRING, nil,          0]
    TOKEN_WORD           =  [:WORD, nil,            0]
    TOKEN_DQPRE          =  [:DQPRE,  nil,          0]
    TOKEN_DQMID          =  [:DQPRE,  nil,          0]
    TOKEN_DQPOS          =  [:DQPRE,  nil,          0]
    TOKEN_NUMBER         =  [:NUMBER, nil,          0]
    TOKEN_VARIABLE       =  [:VARIABLE, nil,        0]
    TOKEN_VARIABLE_EMPTY =  [:VARIABLE, '',         0]
    TOKEN_REGEXP         =  [:REGEXP, nil,          0]


    # HEREDOC has syntax as an argument.
    TOKEN_HEREDOC        =  [:HEREDOC, nil, 0]

    # EPP_START is currently a marker token, may later get syntax
    TOKEN_EPPSTART       =  [:EPP_START, nil, 0]
    TOKEN_EPPEND         =  [:EPP_END, '%>', 2]
    TOKEN_EPPEND_TRIM    =  [:EPP_END_TRIM, '-%>', 3]

    # This is used for unrecognized tokens, will always be a single character.
    TOKEN_OTHER        = [:OTHER,  nil,  1]

    # Keywords are all singleton tokens with pre calculated lengths.
    # Booleans are pre-calculated (rather than evaluating the strings "false" "true" repeatedly.
    #
    KEYWORDS = {
      'case'     => [:CASE,     'case',     4],
      'class'    => [:CLASS,    'class',    5],
      'default'  => [:DEFAULT,  'default',  7],
      'define'   => [:DEFINE,   'define',   6],
      'if'       => [:IF,       'if',       2],
      'elsif'    => [:ELSIF,    'elsif',    5],
      'else'     => [:ELSE,     'else',     4],
      'inherits' => [:INHERITS, 'inherits', 8],
      'node'     => [:NODE,     'node',     4],
      'and'      => [:AND,      'and',      3],
      'or'       => [:OR,       'or',       2],
      'undef'    => [:UNDEF,    'undef',    5],
      'false'    => [:BOOLEAN,  false,      5],
      'true'     => [:BOOLEAN,  true,       4],
      'in'       => [:IN,       'in',       2],
      'unless'   => [:UNLESS,   'unless',   6],
      'function' => [:FUNCTION, 'function', 8],
      'type'     => [:TYPE,     'type',     4],
      'attr'     => [:ATTR,     'attr',     4],
      'private'  => [:PRIVATE,  'private',  7],
    }

    # We maintain two different tables of tokens for the constructs
    # introduced by application management. Which ones we use is decided in
    # +initvars+; by selecting one or the other variant, we select whether we
    # hit the appmgmt-specific code paths
    APP_MANAGEMENT_TOKENS = {
      :with_appm => {
        'application' => [:APPLICATION, 'application',  11],
        'consumes'    => [:CONSUMES,    'consumes',  8],
        'produces'    => [:PRODUCES,    'produces',  8],
        'site'        => [:SITE,        'site',  4]
      },
      :without_appm => {
        'application' => [:APPLICATION_R, 'application',  11],
        'consumes'    => [:CONSUMES_R,    'consumes',  8],
        'produces'    => [:PRODUCES_R,    'produces',  8],
        'site'        => [:SITE_R,        'site',  4]
      }
    }

The Parser
===

The Parser API to use is available via the class `Puppet::Pops::Parser::EvsluatingParser`. It has convenience methods for parsing, validation, and evaluation of the parsed result.

| method                                    | what it does |
| ---                                       | ---          |
| parse_file(filename)                      | reads file, parses and validates the parsed result before returning it
| parse_string(text, filename="")           | parses and validates the given text string, validates and returns the result
| evaluate_file(scope, filename)            | parses, validates, evaluates the parsed result, and returns the result of evaluation
| evaluate_string(scope, text, filename="") | same as evaluate_file, but for a string

Lower level API to be able to get results that are not validated, to do manual validation and other special cases.

| method                                    | what it does |
| ---                                       | ---          |
| parser()                                  | returns the parser
| parser.parse_file(filename)               | parses file without validation
| parser.parse_string(text, filename="")    | parses the string without validation
| assert_and_report(parse_result)           | validates, and reports warnings and errors from result obtained from parser
| evaluate(scope, parse_result)             | evaluates the result obtained from the parser (all, or any AST/model object)
| validate(parse_result)                    | validates the parse_result obtained from the parser and returns validation result


Evaluation
---
Evaluation is very simple in itself - the complicated part is the setup that is required to be able to evaluate all of the
puppet language. For that we need to have a compiler, a node, and a context that is set up with loaders
to load functions and types.

How you do this setup depends on the context where you are doing the parsing.
When writing tests there are helper methods that take care of the setup, or if you are doing this
in logic that is called from a function in puppet. If you want to go "bare metal" you need to do this:

    # in a test.rb file
    # without this, no puppet
    require 'puppet'

    # without this no known environment
    Puppet.initialize_settings

    # node is needed to get a compiler
    node = Puppet::Node.new('example')

    # compiler is needed to get a scope
    compiler = Puppet::Parser::Compiler.new(node)
    scope = compiler.topscope

    # Test that it works
    puts Puppet::Pops::Parser::EvaluatingParser.evaluate_string(scope, "yay")

We can then run that to see it working:

    > bundle exec ruby test.rb
    yay

Depending on hour your ruby and puppet is installed you may need to tweak how you get ruby to run it and find puppet.
Note that the "bare metal" setup uses the settings for Puppet. If you have configured the default "production" environment
with a module path containing modules, you will be able to call functions in modules as well as in puppet.

Note that evaluation done this way does not actually produce a catalog, even if one is built up in the compiler that
is created. How to do a full compilation is beyond the scope of this document.

The following examples assumes a similar setup so a `scope` variable is available.

Simple example - adding with puppet:

    parser = Puppet::Pops::Parser::EvaluatingParser.singleton
    puts parser.evaluate_string(scope, "1 + 1") # prints 2
    puts parser.evaluate_string(scope, "$a = 10; $a + 20") # prints 30

Parsing
---

Parsing is just as simple as evaluation:

    parser = Puppet::Pops::Parser::EvaluatingParser.singleton
    result = parser.parse_string('$a = 1 + 1', 'testing.pp')

With this API, the result that is produced is syntactically and semantically correct (but there may be errors in the logic
that is not detected until it is evaluated), or you will get an exception and the errors and warnings have been logged - just like when compiling a catalog. The `parse_file` method behave the same way, but reads the content from a file instead of being given a String with the source.

### Parsing EPP

Parsing EPP works the same way as parsing regular puppet. Here `EvaluatingEppParser` is used instead of `EvaluatingParser`.
Also not that this class does not have a `singleton` method, so it is required to call `new` to get an instance of it.

    parser = Puppet::Pops::Parser::EvaluatingEppParser.new
    result = parser.parse_string('<%= 1 + 1%>', 'testing.epp')

The result produced works exactly the same way as when parsing regular PP logic.

### The Parse Result

The result of parsing is an instance of `Puppet::Pops::Model::Factory`, on which there is one public method named `model` that returns the Abstract Syntax Tree (AST) that represents the parsed source. The root of this tree is always an instance of
`Puppet::Pops::Model::Program`. This class, along with the other close to 90 classes that make up all kinds of expressions and statements in the puppet language are found in the file `lib/puppet/pops/model/model_meta.rb`

Here is an excerpt from that file showing the `Program` class:

```
  # A Program is the top level construct returned by the parser
  # it contains the parsed result in the body, and has a reference to the full source text,
  # and its origin. The line_offset's is an array with the start offset of each line measured
  # in bytes or characters (as given by the attribute char_offsets). The `char_offsets` setting
  # applies to all offsets recorded in the mode (not just the line_offsets).
  #
  # A model that will be shared across different platforms should use char_offsets true as the byte
  # offsets are platform and encoding dependent.
  # 
  class Program < PopsObject
    contains_one_uni 'body', Expression
    has_many 'definitions', Definition
    has_attr 'source_text', String
    has_attr 'source_ref', String
    has_many_attr 'line_offsets', Integer
    has_attr 'char_offsets', Boolean, :defaultValueLiteral => 'false'
    has_attr 'locator', Object, :lowerBound => 1, :transient => true
  end

```

* The `body` holds the rest of the tree.
* The `definitions` is an Array with references to the parts of the AST that are definitions of some kind; functions, user defined
  resource types, classes, user defined data types. This makes it easier to find these than having to scan through the entire AST.
* The `source_text` is the source text as it was given to the parser.
* The `source_ref` is the filename or name/reference given when parsing
* The `line_offsets` contain the data for the location services - do not use directly
* The `char_offsets` is a boolean indicating if positions are measured in characters (true), or bytes (false) - do not use directly
* The `locator` - is an instance of a `Locator` which should be used to obtain location information (as shown earlier in this document).

### Understanding what the close to 90 AST classes represents

With as many as 90 classes modeling the language, this document cannot fully document all of them.
At the surface level, the names of the classes and their attributes should be fairly self descriptive, and the `model_meta.rb`
is easy to read as it is implemented as an RGen model free from (almost all) implementation
concerns - thus, you will only find the classes, their attributes and the data types of the
attributes in `model_meta.rb`.

As an example, here is the `IfExpression`:

```

  # If expression. If test is true, the then_expr part should be evaluated, else the (optional)
  # else_expr. An 'elsif' is simply an else_expr = IfExpression, and 'else' is simply else == Block.
  # a 'then' is typically a Block.
  #
  class IfExpression < Expression
    contains_one_uni 'test', Expression, :lowerBound => 1
    contains_one_uni 'then_expr', Expression, :lowerBound => 1
    contains_one_uni 'else_expr', Expression
  end
  
```

That should be easy to understand after also having learned that a *Block* is a `BlockEexpression` containing a sequence
of `Expression` instances. In general the parser tries to avoid using a Block if there is just one expression, but there is no guarantee that occurs everywhere.

As an example, the source:

```
$x = if 1 < 2 { 'smaller' } else { 'greater'}

```

produces a `LiteralString` expression in both the `then_expr` and `else_expr` since there is no need for nesting them in block expressions.

We can use the command `puppet parser dump` to look at a human readable output of the AST. While this does not show the name of the
classes of the objects in the AST it helps understanding the structure that is built by the parser. Here is the same example
again, now in dumped form:

```
> puppet parser dump -e '$x = if 1 < 2 { smaller } else { greater }'
(= $x (if (< 1 2)
  (then smaller)
  (else greater)))
```

Here is an example that makes one of the branches a block:

```
puppet parser dump -e '$x = if 1 < 2 { $a = smaller; $a } else { greater }'
(= $x (if (< 1 2)
  (then (block
      (= $a smaller)
      $a
    ))
  (else greater)))
```

As you can see the `then` of the `IfExpression` is now a block.

Note that the output from `parser dump` is informal and not API.

### Tree Walking

The typical operations on an AST involves walking the AST (visiting each object) in some fashion. The simplest form
of walking the tree is to visit each object in parent-before-children in depth first order. Only model objects that
are modeled as *contained* are visited; regular attributes are not. When you look in `model_meta.rb` you see
that an `IfExpression` contains three other expressions, and thus, a visit will visit the `IfExpression` itself, the expression
assigned to `test` (in depth), `then_expr` (in depth), and finally `else_expr` (in depth).


Here is a full example that prints the class of every visited object in an AST resulting from parsing:

    require 'puppet'
    parser = Puppet::Pops::Parser::EvaluatingParser.singleton
    result = parser.parse_string('$x = if 1 < 2 { smaller } else { greater }', 'testing.pp')
    result.model.eAllContents.each {|m|  puts m.class }

This prints the following:

    Puppet::Pops::Model::AssignmentExpression
    Puppet::Pops::Model::VariableExpression
    Puppet::Pops::Model::QualifiedName
    Puppet::Pops::Model::IfExpression
    Puppet::Pops::Model::ComparisonExpression
    Puppet::Pops::Model::LiteralInteger
    Puppet::Pops::Model::LiteralInteger
    Puppet::Pops::Model::QualifiedName
    Puppet::Pops::Model::QualifiedName

As you may have guessed, the root object that receives the `eAllContents` message is not itself included.

    puts result.model.class
    result.model.eAllContents.each {|m|  puts m.class }

Would print out the `Puppet::Pops::Model::Program` before the list of what it contains.

### Polymorphic Dispatch

To help with visiting only some of the objects in a tree, code can be written using the utilities used by
the Puppet validation and evaluation known as [polymorphic dispatch][7].

Here is an example that computes an ABC metric (Assignments, Branches and Conditionals).

require 'puppet'

```
# A Class to compute ABC metric
class AbcMetric

  attr_reader :assignment_count
  attr_reader :branch_count
  attr_reader :condition_count

  def initialize()
    # A visitor shared by all instances of this class
    # It performs a polymorphic visit of the object to a method
    # named 'abc_' and the name of the class without any additional
    # arguments. The receiver must be `nil` and given when calling
    # `visit_this`
    #
    @@abc_visitor       ||= Puppet::Pops::Visitor.new(nil, "abc", 0, 0)

    # initialize counters
    @assignment_count = 0
    @branch_count = 0
    @condition_count = 0
  end

  # Computes ABC metric of an AST
  # This is the method that a user of the AbcMetric calls
  #
  def compute_abc(target)
    target.eAllContents.each {|m|  abc(m) }
    # return the three resulting counts
    [@assignment_count, @branch_count, @condition_count]
  end

  protected

  # visit the object by using the polymorphic visitor
  def abc(o)
    # do a polymorphic visit
    @@abc_visitor.visit_this_0(self, o)
  end

  # Catch all that are not counted
  def abc_Object(o)
    # nothing to count here
  end

  def abc_AssignmentExpression(o)
    @assignment_count += 1
  end

  # Catch the different kinds of calls; FunctionCallExpression,
  # CallNamedFunctionExpression, and MethodCallExpression
  #
  def abc_CallExpression(o)
    @branch_count += 1
  end

  def abc_IfExpression(o)
    @condition_count += 1
  end

  # other conditionals left as an exercise
end

parser = Puppet::Pops::Parser::EvaluatingParser.singleton

# A Puppet Language source with:
# - one assignment
# - two branches (function calls)
# - one conditional
#
source = <<-EOF
function s { 'smaller' }
function g { 'greater' }

$x = if 1 < 2 { s() } else { g() }
EOF

# parse it
result = parser.parse_string(source, 'testing.pp')

# compute and print ABC metric
puts AbcMetric.new.compute_abc(result.model)
```

Prints `1 2 1` when executed.

This example is only the beginning of a real ABC metric calculator. For a more comprehensive ABC metric calculation
check out [Danzilo's Implementation][1].

See [Puppet Internals - Polymorphic Dispatch][7] for more details about polymorphic dispatch.
Note that since that article was written some additional methods have been added to optimize the performance
of the polymorphic dispatch. Where the blog post ties the visitor to `self`, the examples here tie them to
`nil` and instead give the receiver when calling the visitor. Also used here is the optimized method
`call_this_0` which performs faster than just `call_this` for 0 arguments (there are variants for `_1`, `_2`, `_3` args
as well that are also optimized).

### Validation

Writing validation is a typical task to perform on the AST. The [source of the Puppet 4.x language validator][2] shows
a much larger example of polymorphic dispatch using multiple visitors for different purposes.

In the `initialize` method you find this logic:

    @@check_visitor       ||= Visitor.new(nil, "check", 0, 0)
    @@rvalue_visitor      ||= Visitor.new(nil, "rvalue", 0, 0)
    @@hostname_visitor    ||= Visitor.new(nil, "hostname", 1, 2)
    @@assignment_visitor  ||= Visitor.new(nil, "assign", 0, 1)
    @@query_visitor       ||= Visitor.new(nil, "query", 0, 0)
    @@top_visitor         ||= Visitor.new(nil, "top", 1, 1)
    @@relation_visitor    ||= Visitor.new(nil, "relation", 0, 0)
    @@idem_visitor        ||= Visitor.new(self, "idem", 0, 0)

That defines visitors that perform the following:

* check - semantic checking
* rvalue - is the value a rvalue or not
* hostname - is this a valid hostname
* assignment - is the left expression in an assignment something that can be assigned to
* query - is this a valid query expression in a collector
* top - are expression that are allowed only at the "top" nested or not
* relation - checks expression involved in relationship expressions ->, ->, ~>, <~
* idem - checks if an expression is productive or not

Here is an excerpt from `checker4_0.rb` that deals with validation of assignment:

    def assign_VariableExpression(o, via_index)
      varname_string = varname_to_s(o.expr)
      if varname_string =~ Patterns::NUMERIC_VAR_NAME
        acceptor.accept(Issues::ILLEGAL_NUMERIC_ASSIGNMENT, o, :varname => varname_string)
      end
      # Can not assign to something in another namespace (i.e. a '::' in the name is not legal)
      if acceptor.will_accept? Issues::CROSS_SCOPE_ASSIGNMENT
        if varname_string =~ /::/
          acceptor.accept(Issues::CROSS_SCOPE_ASSIGNMENT, o, :name => varname_string)
        end
      end
    end

    def assign_AccessExpression(o, via_index)
      # Are indexed assignments allowed at all ? $x[x] = '...'
      if acceptor.will_accept? Issues::ILLEGAL_INDEXED_ASSIGNMENT
        acceptor.accept(Issues::ILLEGAL_INDEXED_ASSIGNMENT, o)
      else
        # Then the left expression must be assignable-via-index
        assign(o.left_expr, true)
      end
    end

    def assign_LiteralList(o, via_index)
      o.values.each {|x| assign(x) }
    end

    def assign_Object(o, via_index)
      # Can not assign to anything else (differentiate if this is via index or not)
      # i.e. 10 = 'hello' vs. 10['x'] = 'hello' (the root is reported as being in error in both cases)
      #
      acceptor.accept(via_index ? Issues::ILLEGAL_ASSIGNMENT_VIA_INDEX : Issues::ILLEGAL_ASSIGNMENT, o)
    end

There are several noteworthy things here:

* The `assign_VariableExpression` checks that
  * the name of a variable is not numeric (it is illegal to assign to `$0`, `$1`, etc)
  * the assignment is not to a fully qualified variable
    * this is a configurable validation as this was once allowed
  * the `acceptor` is an object that knows about the configuration of *issues* and knows how they should be reported
  * A warning/error is generated by calling `accept` on the `acceptor`. The issue is a symbolic reference to an instance
    of `Issue` with arguments that makes it possible for it to format a message.

This split of the functionality is to make it easier to reuse the validator. Contrast this implementation with one
that would immediately raise an error; it would then be impossible to reuse the validator for finding all reported issues
as it would stop immediately. What if we want to run a sequence of validations, say to collect the errors and warnings
from multiple files before reporting?

The handling of issues as separate objects was done to not having to repeat the same error text over and over
and to make it easier to translate the warnings/errors. When doing so, the different kinds of issues gets their own
identity (for example `Issues::ILLEGAL_ASSIGNMENT_VIA_INDEX`).

### Issues

The issues used by the Puppet validator is [found here][3]. It contains both the classes that make up the core of the
issues feature, and it defines the various issue constants (for example `Issues::ILLEGAL_ASSIGNMENT_VIA_INDEX`).

You can write your own issues module. Here is an example

    module MyModule::Issues
      # (see Puppet::Pops::Issues#issue)
      def self.issue (issue_code, *args, &block)
        Puppet::Pops::Issues.issue(issue_code, *args, &block)
      end

      MYMODULE_FILE_NOT_FOUND = issue :MYMODULE_FILE_NOT_FOUND do
        "The mymodule configuration file: #{semantic} can not be found."
      end

      # etc
    end

The issue system has support for common tasks related to producing messages.

* It knows how to name AST and many ruby objects via a LabelProvider.
* It knows who to "semantically blame" (given it the call too `acceptor.accept`) - this is the `semantic` reference in 
  the example.
* It knows how to produce an article ("a", "an", "the") in lower or up cased version of a label
* Understands that a semantic object may contain a reference to a `Locator` which makes it possible to get the
  source code position, or the source of the expression

The call to `acceptor.accept` is given the semantic object (the thing to "blame"/the thing that tells us the location),
and arguments to the issue. We saw this example in the assignment checker earlier:

    acceptor.accept(Issues::ILLEGAL_NUMERIC_ASSIGNMENT, o, :varname => varname_string)

Here, the `Issues::ILLEGAL_NUMERIC_ASSIGNMENT` is a reference to the constant in the Issues object, the `o` is
the semantic object, and the rest of the arguments to the error are set as using an options hash, here setting
`:varname` to the string that holds the variable name.

An issue such as `ILLEGAL_NUMERIC_ASSIGNMENT` that takes arguments looks like this:

    # Assignment cannot be made to numeric match result variables
    ILLEGAL_NUMERIC_ASSIGNMENT = issue :ILLEGAL_NUMERIC_ASSIGNMENT, :varname do
      "Illegal attempt to assign to the numeric match result variable '$#{varname}'. Numeric variables are not assignable"
    end

The parameters are simply given as extra arguments to the call to `issue` - here defining that `:varname` is the name
of an argument that must be supplied by the caller of `acceptor.accept`.

The [Label Provider][4] has these operations available via `label`

* `label(o)` - same as `label.label(o)` - produces a name of the object o (for example 'Literal Integer')
* `label.a_an(o)`, `label.a_an_uc(o)` - produces an indefinite article in lower case or with initial upper case
* `label.the(o)`, `label.the_uc(o)` - produces a definitive article in lower case or with initial upper case
* `label.plural_s(count, text)` - adds a plural 's' to text if count > 1

Look at the [issues configured for the parser][4] for examples of using these. There you will also see calls to
`hard_issue` - those are issues that cannot be configured to be a warning.

Comprehensive Example - Performing extra validation
---------------------------------------------------

In this example we will add some additional custom validation. Starting from this simple example where parsing
and the build in validation is performed for us automatically as errors and warnings are logged and an exception raised
if there were any errors.

    require 'puppet'
    parser = Puppet::Pops::Parser::EvaluatingParser.singleton
    result = parser.parse_string('$x = if 1 < 2 { smaller } else { greater }', 'testing.pp')

The first thing to do is to instead use the lower level method to get the parsing done without validation.

    require 'puppet'
    parser = Puppet::Pops::Parser::EvaluatingParser.singleton
    result = parser.parser.parse_string('$x = if 1 < 2 { smaller } else { greater }', 'testing.pp')
    # We now have a parse result that has not been validated
    # It is however free of lexical and hard syntax errors as those raise an exception

At this point, we could continue by calling `assert_and_report(parse_result)` but that would only get us
what the higher level API gave us, so we need to look inside that to be able to do something different.

The `assert_and_report` method does some house keeping regarding source reference (depending on the
origin of the result, file, string a handcrafted piece of AST etc. and handle if the result is nil)
and then does these two lines:

    validation_result = validate(parse_result)
    IssueReporter.assert_and_report(validation_result, :emit_warnings => true)

The `IssueReporter` part is not suitable in this example, since it is designed to be used at runtime
when compiling. It needs a configured logging destination and will not produce any output to the CLI
unless there are errors (or the loggers are configured to do that). In the example below we will
use a different way to report the found warnings and errors.

So what does `validate` do? Here is that logic:

    resulting_acceptor = acceptor()
    validator(resulting_acceptor).validate(parse_result)
    resulting_acceptor

The `acceptor` method simply does this:

    Validation::Acceptor.new

An `Acceptor` is basically a container of `Diagnostic`. They together with the classes `DiagnosticFormatter`,
`DiagnosticFormatterPuppetStyle`, `DiagnosticProducer`, `Factory`, and `SeverityProducer` are
defined in [validation.rb][5]. They form the foundation for  the `assert_and _report` method.
The example code below shows how to configure them into a working solution.

So, now we have something that can hold "errors and warnings" and do operations on them, know how severe they are
etc. Before looking at what you can do with that, we need to also look at the side that produces diagnostics; the
`Validator` and how it all comes together - and that is the role of the `Factory`.

The `Puppet::Pops::Validation::Factory` provides a base implementation of what is required when performing
a validation of some sort. It needs to have certain details filled in - like what the severity of different
issues are going to be (warning, deprecation, error or ignored). It needs to know how to represent
things in string form etc.

And finally, the actual checker in this validation setup that looks at each piece that needs validation,
performs the check, and determines if there is a potential issue or not.

You can think of this as:

* the parse result is the patient
* the acceptor is a diagnostics producer, a diagnostician which translates to a doctor
* the checker corresponds to a technician - someone that listens to the patients heart, checks
  for a Babinski reflex, check if pupils are dilated, takes the temp, and so forth.
* the checker makes notes about the notworthy conditions (normal things are not noted) - this corresponds
  to the calls to the `acceptor.accept` calls
* the patient may be sent to different technicians for different tests
* the doctor finally looks at the issues and determines if the patient is well, unfit, ill etc.

The current validator configuration in puppet is quite simple. The doctor simply looks at the logged issues
and directly translates them into warning or errors `Diagnostics` without considering the "full picture".
It is fully possible to use a more advanced diagnostician that looks at all logged things at treats them
as symptoms and then produces additional diagnostics (or replaces the notes of symptoms with a diagnose).

This is best illustrated with working code ([also in this gist][6]):

All things discussed so far comes into play here, so you may need to refer back in this document
to understand some of the details of what is going on.

```
require 'puppet'

# Example of a module setting everything up to perform custom
# validation of an AST model produced by parsing puppet source.
#
module MyValidation

  # A module for the new issues that the this new kind of validation will generate
  #
  module Issues
    # (see Puppet::Pops::Issues#issue)
    # This is boiler plate code
    def self.issue (issue_code, *args, &block)
      Puppet::Pops::Issues.issue(issue_code, *args, &block)
    end

    INVALID_WORD = issue :INVALID_WORD, :text do
      "The word '#{text}' is not a real word."
    end
  end

  # This is the class that performs the actual validation by checking input
  # and sending issues to an acceptor.
  #
  class MyChecker
    attr_reader :acceptor
    def initialize(diagnostics_producer)
      @@bad_word_visitor       ||= Puppet::Pops::Visitor.new(nil, "badword", 0, 0)
      # add more polymorphic checkers here

      # remember the acceptor where the issues should be sent
      @acceptor = diagnostics_producer
    end

    # Validates the entire model by visiting each model element and calling the various checkers
    # (here just the example 'check_bad_word'), but a series of things could be checked.
    #
    # The result is collected by the configured diagnostic provider/acceptor
    # given when creating this Checker.
    # 
    # Returns the @acceptor for convenient chaining of operations
    #
    def validate(model)
      # tree iterate the model, and call the checks for each element

      # While not strictly needed, here a check is made of the root (the "Program" AST object)
      check_bad_word(model)

      # Then check all of its content
      model.eAllContents.each {|m| check_bad_word(m) }
      @acceptor
    end

    # perform the bad_word check on one AST element
    # (this is done using a polymorphic visitor)
    #
    def check_bad_word(o)
      @@bad_word_visitor.visit_this_0(self, o)
    end

    protected

    def badword_Object(o)
      # ignore all not covered by an explicit badword_xxx method
    end

    # A bare word is a QualifiedName
    #
    def badword_QualifiedName(o)
      if o.value == 'bigly'
        acceptor.accept(Issues::INVALID_WORD, o, :text => o.value)
      end
    end
  end

  class MyFactory < Puppet::Pops::Validation::Factory
    # Produces the checker to use
    def checker(diagnostic_producer)
      MyChecker.new(diagnostic_producer)
    end

    # Produces the label provider to use.
    #
    def label_provider
      # We are dealing with AST, so the existing one will do fine.
      # This is what translates objects into a meaningful description of what that thing is
      #
      Puppet::Pops::Model::ModelLabelProvider.new()
    end

    # Produces the severity producer to use. Here it is configured what severity issues have
    # if they are not all errors. (If they are all errors this method is not needed at all).
    #
    def severity_producer
      # Gets a default severity producer that is then configured below
      p = super

      # Configure each issue that should **not** be an error
      #
      p[Issues::INVALID_WORD]                 = :warning

      # examples of what may be done here
      # p[Issues::SOME_ISSUE]           = <some condition> ? :ignore : :warning
      # p[Issues::A_DEPRECATION]        = :deprecation

      # return the configured producer
      p
    end
  end

  # We create a diagnostic formatter that outputs the error with a simple predefined
  # format for location, severity, and the message. This format is a typical output from
  # something like a linter or compiler.
  # (We do this because there is a bug in the DiagnosticFormatter's `format` method prior to
  # Puppet 4.9.0. It could otherwise have been used directly.
  #
  class Formatter < Puppet::Pops::Validation::DiagnosticFormatter
    def format(diagnostic)
      "#{format_location(diagnostic)} #{format_severity(diagnostic)}#{format_message(diagnostic)}"
    end
  end
end

# -- Example usage of the new validator

# Get a parser
parser = Puppet::Pops::Parser::EvaluatingParser.singleton

# parse without validation
result = parser.parser.parse_string('$x = if 1 < 2 { smaller } else { bigly }', 'testing.pp')
result = result.model

# validate using the default validator and get hold of the acceptor containing the result
acceptor = parser.validate(result)

# -- At this point, we have done everything `puppet parser validate` does except report the errors
# and raise an exception if there were errors.

# The acceptor may now contain errors and warnings as found by the standard puppet validation.
# We could look at the amount of errors/warnings produced and decide it is too much already
# or we could simply continue. Here, some feedback is printed:
#
puts "Standard validation errors found: #{acceptor.error_count}"
puts "Standard validation warnings found: #{acceptor.warning_count}"

# Validate using the 'MyValidation' defined above
#
validator = MyValidation::MyFactory.new().validator(acceptor)

# Perform the validation - this adds the produced errors and warnings into the same acceptor
# as was used for the standard validation
#
validator.validate(result)

# We can print total statistics
# (If we wanted to generated the extra validation separately we would have had to
# use a separate acceptor, and then add everything in that acceptor to the main one.)
#
puts "Total validation errors found: #{acceptor.error_count}"
puts "Total validation warnings found: #{acceptor.warning_count}"

# Output the errors and warnings using a provided simple starter formatter
formatter = MyValidation::Formatter.new

puts "\nErrors and warnings found:"
acceptor.errors_and_warnings.each do |diagnostic|
  puts formatter.format(diagnostic)
end

```

When run, the above produces this output:

```
Standard validation errors found: 0
Standard validation warnings found: 0
Total validation errors found: 0
Total validation warnings found: 1

Errors and warnings found:
testing.pp:1:27: The word 'bigly' is not a real word.
```

### Variations on Validation

#### Accepting into an intermediate Acceptor

In the example we first performed the standard validation and then continued to add more issues as found
by the new validator. We can do that another way by collecting each validator's issues separately.

    acceptor = parser.validate(result)
    acceptor2 = Puppet::Pops::Validation::Acceptor.new
    validator = MyValidation::MyFactory.new().validator(acceptor2)
    validator.validate(result)

We can then add those to the first acceptor:

    acceptor.accept(acceptor2)

[1]: https://github.com/danzilio/puppet-lint-metrics-check/blob/master/lib/puppet-lint/metrics/abc.rb
[2]: https://github.com/puppetlabs/puppet/blob/master/lib/puppet/pops/validation/checker4_0.rb
[3]: https://github.com/puppetlabs/puppet/blob/master/lib/puppet/pops/issues.rb
[4]: https://github.com/puppetlabs/puppet/blob/master/lib/puppet/pops/label_provider.rb
[5]: https://github.com/puppetlabs/puppet/blob/master/lib/puppet/pops/validation.rb
[6]: https://gist.github.com/hlindberg/3f08f1c4d9d2b824eee003a48714edd8
[7]: https://puppet-on-the-edge.blogspot.com.mt/2014/02/puppet-internals-polymorphic-dispatch.html


