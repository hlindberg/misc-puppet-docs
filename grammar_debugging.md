Grammar Debugging
===
How to debug the Puppet Grammar

Understanding what the grammar is doing can be done by reading its static output and manually
tracing through what will happen when running.

In the directory: `puppet/pops/grammar` - run this command:

    make egrammar.output

Will produce an output file in text form.

This file is however quite hard to read and it is easy to get lost after just a few steps.

You can also get the parser to output each shift/reduce and follow how the parser builds
up the resulting expression. To do this the parser must be generated for debugging. (It is much
slower, so this should not be done by default. (And if you generate a parser for debugging,
never ever check it in).

Modify the makefile to read like this:

    eparser.rb: egrammar.ra
        racc -g -o$@ egrammar.ra

It is the -g that adds debugging. Remove the -g when done with debugging.
If nothing happens you may need to touch the egrammar.ra file.

Next step is to get some output. There is no instrumentation for this. You need to modify
parser_support.rb, and modify the beginning of the _parse method to read like this:

      def _parse()
        begin
          @yydebug = true
          @racc_debug_out = $stdout
          require 'debugger'; debugger
          main = yyparse(@lexer,:scan)
          . . .

There is normally just a @yydebug = false at this place (to turn off debugging).
The @racc_debug_out is by default directed to $stderr (which may be redirected depending on
how you are running), change that to $stdout.

When parsing, use only small snippets that trigger the problem or you will drown in output.
I use a breakpoint, so I can do 'next' over the parsing and immediately see the result (and terminate if I did not like what I got, tweak, regenerate and run again until happy).

Here is a session as an example:

    $ bundle exec puppet apply --parser future -e 'notice [1]'

    /Users/henrik/git/puppet/lib/puppet/pops/parser/parser_support.rb:190
    main = yyparse(@lexer,:scan)
    
    [185, 194] in /Users/henrik/git/puppet/lib/puppet/pops/parser/parser_support.rb
       185    def _parse()
       186      begin
       187        @yydebug = true
       188        @racc_debug_out = $stdout
       189        require 'debugger'; debugger
    => 190        main = yyparse(@lexer,:scan)
       191        # #Commented out now because this hides problems in the racc grammar while developing
       192        # # TODO include this when test coverage is good enough.
       193        #      rescue Puppet::ParseError => except
       194        #        except.line ||= @lexer.line

    (rdb:1) next
    
    read    :NAME(NAME) {:line=>1, :pos=>1, :offset=>0, :length=>6, :value=>"notice"}

    shift   NAME
            [ (NAME {:line=>1, :pos=>1, :offset=>0, :length=>6, :value=>"notice"}) ]
    
    goto    55
            [ 0 55 ]
    
    reduce  NAME --> name
            [ (name notice) ]
    
    goto    33
            [ 0 33 ]
    
    reduce  name --> text_or_name
            [ (text_or_name notice) ]
    
    goto    30
            [ 0 30 ]
    
    reduce  text_or_name --> literal_expression
            [ (literal_expression notice) ]
    
    goto    15
            [ 0 15 ]
    
    reduce  literal_expression --> primary_expression
            [ (primary_expression notice) ]
    
    goto    35
            [ 0 35 ]
    
    read    :LISTSTART(LISTSTART) {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}
    
    reduce  primary_expression --> call_function_expression
            [ (call_function_expression notice) ]
    
    goto    14
            [ 0 14 ]
    
    reduce  call_function_expression --> higher_precedence
            [ (higher_precedence notice) ]
    
    goto    9
            [ 0 9 ]
    
    reduce  higher_precedence --> expression
            [ (expression notice) ]
    
    goto    10
            [ 0 10 ]
    
    reduce  expression --> resource_expression
            [ (resource_expression notice) ]
    
    goto    8
            [ 0 8 ]
    
    reduce  resource_expression --> relationship_expression
            [ (relationship_expression notice) ]
    
    goto    7
            [ 0 7 ]
    
    reduce  relationship_expression --> any_expression
            [ (any_expression notice) ]
    
    goto    6
            [ 0 6 ]
    
    reduce  any_expression --> syntactic_statement
            [ (syntactic_statement notice) ]
    
    goto    5
            [ 0 5 ]
    
    reduce  syntactic_statement --> syntactic_statements
            [ (syntactic_statements [notice]) ]
    
    goto    4
            [ 0 4 ]
    
    shift   LISTSTART
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) ]
    
    goto    48
            [ 0 4 48 ]
    
    read    :NAME(NAME) {:line=>1, :pos=>9, :offset=>8, :length=>1, :value=>"1"}
    
    shift   NAME
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (NAME {:line=>1, :pos=>9, :offset=>8, :length=>1, :value=>"1"}) ]
    
    goto    55
            [ 0 4 48 55 ]
    
    reduce  NAME --> name
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (name 1) ]
    
    goto    33
            [ 0 4 48 33 ]
    
    reduce  name --> text_or_name
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (text_or_name 1) ]
    
    goto    30
            [ 0 4 48 30 ]
    
    reduce  text_or_name --> literal_expression
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (literal_expression 1) ]
    
    goto    15
            [ 0 4 48 15 ]
    
    reduce  literal_expression --> primary_expression
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (primary_expression 1) ]
    
    goto    35
            [ 0 4 48 35 ]
    
    read    :RBRACK(RBRACK) {:line=>1, :pos=>10, :offset=>9, :length=>1, :value=>"]"}
    
    reduce  primary_expression --> call_function_expression
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (call_function_expression 1) ]
    
    goto    14
            [ 0 4 48 14 ]
    
    reduce  call_function_expression --> higher_precedence
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (higher_precedence 1) ]
    
    goto    9
            [ 0 4 48 9 ]
    
    reduce  higher_precedence --> expression
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (expression 1) ]
    
    goto    122
            [ 0 4 48 122 ]
    
    reduce  expression --> expressions
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (expressions [1]) ]
    
    goto    125
            [ 0 4 48 125 ]
    
    shift   RBRACK
            [ (syntactic_statements [notice]) (LISTSTART {:line=>1, :pos=>8, :offset=>7, :length=>1, :value=>"["}) (expressions [1]) (RBRACK {:line=>1, :pos=>10, :offset=>9, :length=>1, :value=>"]"}) ]
    
    goto    224
            [ 0 4 48 125 224 ]
    
    reduce  LISTSTART expressions RBRACK --> array
            [ (syntactic_statements [notice]) (array ([] 1)) ]
    
    goto    25
            [ 0 4 25 ]
    
    reduce  array --> literal_expression
            [ (syntactic_statements [notice]) (literal_expression ([] 1)) ]
    
    goto    15
            [ 0 4 15 ]
    
    reduce  literal_expression --> primary_expression
            [ (syntactic_statements [notice]) (primary_expression ([] 1)) ]
    
    goto    35
            [ 0 4 35 ]
    
    read    false($end) false
    
    reduce  primary_expression --> call_function_expression
            [ (syntactic_statements [notice]) (call_function_expression ([] 1)) ]
    
    goto    14
            [ 0 4 14 ]
    
    reduce  call_function_expression --> higher_precedence
            [ (syntactic_statements [notice]) (higher_precedence ([] 1)) ]
    
    goto    9
            [ 0 4 9 ]
    
    reduce  higher_precedence --> expression
            [ (syntactic_statements [notice]) (expression ([] 1)) ]
    
    goto    10
            [ 0 4 10 ]
    
    reduce  expression --> resource_expression
            [ (syntactic_statements [notice]) (resource_expression ([] 1)) ]
    
    goto    8
            [ 0 4 8 ]
    
    reduce  resource_expression --> relationship_expression
            [ (syntactic_statements [notice]) (relationship_expression ([] 1)) ]
    
    goto    7
            [ 0 4 7 ]
    
    reduce  relationship_expression --> any_expression
            [ (syntactic_statements [notice]) (any_expression ([] 1)) ]
    
    goto    6
            [ 0 4 6 ]
    
    reduce  any_expression --> syntactic_statement
            [ (syntactic_statements [notice]) (syntactic_statement ([] 1)) ]
    
    goto    63
            [ 0 4 63 ]
    
    reduce  syntactic_statements syntactic_statement --> syntactic_statements
            [ (syntactic_statements [notice, ([] 1)]) ]
    
    goto    4
            [ 0 4 ]
    
    reduce  syntactic_statements --> statements
            [ (statements [(invoke notice ([] 1))]) ]
    
    goto    2
            [ 0 2 ]
    
    reduce  statements --> program
            [ (program (invoke notice ([] 1))) ]
    
    goto    1
            [ 0 1 ]
    
    shift   $end
            [ (program (invoke notice ([] 1))) ($end false) ]
    
    goto    61
            [ 0 1 61 ]
    
    shift   $end
            [ (program (invoke notice ([] 1))) ($end false) ($end false) ]
    
    goto    134
            [ 0 1 61 134 ]
    
    accept

       
Even if you are not immediately familiar with the grammar, you can pretty much guess what is
going on here. Notice that the built AST is shown in lisp notation form, so you can see how the parser stacks up expression snippets (i.e. 'shift') and then combines them into an expression ('reduce'). A 'shift' pushes a token, or result onto the stack, the state is then shifted ('goto').
A 'reduce' pops a state and may result in an actual reduction on the stack (many rules simply result in the same value).

As an example look at the rule that shifts RBRACK, it then shifts to a state that results
in `LISTSTART expressions RBRACK --> array`, and this is where the parser decides it has "seen an array". You also see the "lisp" notation; `(syntactic_statements [notice]) (array ([] 1))` which consists of a mix of rule names (`syntactic_statements`, `array`) and resulting values `[notice]` (a ruby array with a NAME token having value `notice`, and `([] 1)` the puppet model for the `[]` operator with `1` as an argument.

As an exercise, it is useful to start with following the actions taken once RBRACK has been seen until it reaches the end with the `(program (invoke notice ([] 1)))` - this part (the unwinding/reduction) is somewhat easier to follow than the nesting that takes place at the beginning until you are familiar with the rules in the grammar.

The state numbers are useful to find the details in the output file. If you are surprised why the
next step was a particular shift or reduce, you can see the table of where different input
takes the parser next.

The above relies on the following method having been added to the Puppet::Pops::Model::Factory:

    # Useful when debugging as this dumps the expression in compact form
    def to_s
      @@dumper ||= Puppet::Pops::Model::ModelTreeDumper.new
      @@dumper.dump(self)
    end

as you would otherwise get an unintelligent listing of ruby instance references. If you are debugging an older version of the grammar / factory, you probably want to add that method. (And yes, while the parser is building the result, each fragment of the expression tree is wrapped in an instance of Factory - it acts as a builder that can manipulate the model elements. (But that is a topic for another post).

- henrik
