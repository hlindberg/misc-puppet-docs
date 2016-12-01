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

    # Allow simpler call when not caring about getting the actual acceptor
    def diagnostic_producer(acceptor=nil)
      acceptor.nil? ? super(Puppet::Pops::Validation::Acceptor.new) : super(acceptor)
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
