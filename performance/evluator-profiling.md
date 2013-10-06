Evaluator Profiling
===
An important requirement for the new evaluator is performance. It can not be slower than the existing evaluator.

Thus having good tools for performance measurement is essential.

This document describes how to use ruby-prof and qcachegrind when profiling.

Rspec
---
The easiest way to run something is to run it as an rspec test.

In the evaluator branch, support for using ruby-prof has been added to the rspec helper.
(It is skipped if ruby prof is not installed), and profiling is only turned on if explicitly asked
for.

Installation
---
### Install ruby-prof

     sudo gem install ruby-prof

### Gemfile

I have the following in my `Gemfile.local`

        if RUBY_VERSION == "1.9.3"
         gem "debugger", :require => false
         gem "ruby-prof", :require => true
        end
        if RUBY_VERSION == "2.0.0"
         gem "byebug", :require => false
         gem "ruby-prof", :require => true
        end

Marking an individual test for profiling
---
It is possible to get profiling for all executed tests, but it is also possible to only
turn it on for specific tests. (When running it for all tests, you get A LOT OF DATA (and it is very slow).

    it "simple lexing", :profile => true do
       lexer = Puppet::Pops::Parser::Lexer.new
       code = 'if true { 10 + 10 } else { "interpolate ${foo} andn stuff" }'
       10000.times {lexer.string = code; lexer.fullscan }
    end

Here ignoring the actual testing (which can be done by using Benchmark to measure and then
asserting that there was no performance regression. (Which is tricky since different machines
have different speed and the result needs to be normalized, etc.).

Running the profiling
---
The rspec helper makes use of two environment variables PROFILE (turn on profiling if 'true', and
profile all examples if 'all'), and PROFILEOUT which must be set to the path where you want the output (I typically use '.').

To run only the example above I use:

    PROFILE=true PROFILEOUT=. rspec spec/unit/pops/parser/lexer_spec.rb -e 'simple lexing'
     
The result is then a file in the current directory:

     callgrind.simple-lexing.1381011731.trace
     
Viewing the result
---
The result can be viewed with qcachegrind (graphical UI).

Google for how to install.
You must have graphviz installed

Open the callgrind file from above in qcachegrind and poke around. It helps you find the most expensive parts quickly.
