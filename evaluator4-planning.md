Planning Evaluator 4
===

To ease the merging, make these changes in the following order:

* Merge Heredoc
* Merge Template Support
* Make sure all lexer/parser PRs have been merged as well
* Remove alternative syntaxes for lambdas
* Additional fixes/issues for future parser

At this point, the --parser future can be released in 3.4 with evaluation using 3.x AST

Future Evaluator:

* Rebase Evaluator branch onto master (the changes above), then deal with
  * changes in evaluator required by heredoc / templates

* Error Handling
  The experimental work on evaluator raises very simple exceptions (ArgumentError). The
  ISSUE system should be used throughout the implementation. This can be done in parallel
  with continued development on the actual evaluator, i.e. make it work for one thing first,
  then change all the others.
  This approach makes it faster to develop, it is not meaningful to invest in identified
  errors and fancy formatting until it is clear that the implementation should work a certain way.
  
* Detailed actions per "operator". There are many operators / features in the language that needs
  to be discussed and decision made. These are listed in another document. An agenda for discussing  
  these, and driving them to resolution is needed.
    * Identify decision that have impact on architecture / implementation first and decide on those 
      first. (look at decisions already made, some changes may require more extensive redesign).
  
* Performance work. This can start by creating a performance testing environment, creating
  test data etc. This work should be relevant to Puppet 3.x as well.
    * Measuring of Ruby constructs. We found certain Ruby constructs to have somewhat surprising
      performance characteristics. It is important to know if these characteristics are the same
      across different Ruby implementations (or we may be sub optimizing for some).
    * The types of operations performed in the lexer are of particular interest, and so are the
      operations performed by the polymorphic dispatch.
    * String compare vs regexp, how to match regexp the fastest way, freezing strings or not, are 
      frozen arrays faster to use than non frozen, hashes faster than arrays, etc.
      
* Code coverage - no code coverage for evaluator (nor parser) done to date. Need to know how much
  improvement needed in tests.
  
* Break down actual evaluator implementation into subtasks allowing for parallel work. Currently
  not implemented:
  * CollectExpression, Query, ExportedQuery, VirtualQuery
  * ResourceExpressions, AttributeOperation
  * Definitions; Node, Class, ResourceType
  
* Handle various aspects of parsing/evalation
  * lazy evaluation, new evaluator is not a call to safeeval on code, which old parts of the
    system needs to be modified, how for lowest impact
  * file caching
  * known resource types / environments
  * changes to scope (some already done)
  * language changes to semantics scoping / naming etc. ?
  
* Decide and implement Puppet Specific runtime objects. (May have big negative performance impact)
  (i.e our own PObjects for all data types)
    
* Decide on PuppetType (i.e. writing types in puppet language, not the type system) work
  should be brushed up, or broken out for future use.
    
* Write a proper language specification

  