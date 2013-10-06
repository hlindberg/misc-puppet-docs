Lexer Performance Notes
===

All operations in the lexer are time critical since it visits every character in every manifest.

One of the heavy operations (shown in profiling) is computing the information for error messages.
There are several strategies that can be deployed to speed this up.

The older lexer computed line information as part of regular lexing (checking for scanning past
a \n character). With the desire to also point out where on the line a particular token comes from
(its line, its offset on the line, as well as its length), doing this while processing tokens became quite problematic.

There are two basic strategies:
* make it faster
* avoid computing details

The expensive methods are:
* `Lexer.scan` (it does lots of different things)
* `Lexer.munge_token`
* `Lexer.position_in_source`

Measurements indicates that position_in_source costs 10-20% of the total time.

String scanning comes in at 7%.

The test
---
    lexer = Puppet::Pops::Parser::Lexer.new
    code = 'if true { 10 + 10 } else { "interpolate ${foo} andn stuff" }'
    10000.times {lexer.string = code; lexer.fullscan }

Takes 3.3 seconds to run as an rspec test. It takes 21 seconds to run with ruby-prof turned
on.


Avoiding to compute position details
---
An instance of a Locator is used in the lexer. Each token receives a hash with the computed values
(start_line, pos, offset, and length). It could instead just keep the offset and end_offset
plus a reference to the Locator.

The locator contains an array of all offsets i.e. [0, 10, 43, 78] marking the offsets at the start of each line.

Naturally, this object would be retained for as long as the tokens are kept.
The location information is then transferred to the resulting model object, and set in a pops
adapter (on the model object). The lazy evaluation strategy could just pass the offsets and
locator on.

This strategy is probably the best since in only the location of a few model objects are ever used
and when used they are only used in error messages. This avoids millions of calls to compute
the offset. (In the test roughly a hundred thousand calls).

Some calculation must still be done, or the entire source string (content of the file) will also need to be kept in memory as long as something refers to the locator instance. (But this can also
be optimized).

Make it faster
---

### Faster line computation (Locator.line_for_offset)

The problem is, given an offset (cheap, obtained from the stringscanner) produce the line number.

The current implementation uses Array.index and a block that checks `|x| x > offset` - this is bad
for large files since it always starts the search from the beginning, so the larger the file, the slower it will get.

When running on Ruby 2.0.0 Array has a `bsearch` method (which returns the element, not the line).
In this case, the lines can be stored as [[0,0], [1, 10], [2, 43], ... ] instead, and then using
`Array.bsearch {|x[ x[1]> offset}[0]` as the answer. 

Which is faster probably depends on the size of the array. Measurement will tell.

Also tried:

* Quick manual testing with Ranges proved them to be slower (no profiling). 
* Testing with red/green tree was slower (probably because it is implemented in Ruby)
* Use of bsearch written in Ruby is probably not worth trying (although it may have good effect
  on huge files).

### Faster character positions

In Ruby 1.9 the stringscanner operates at byte offsets, and there is no way to cheaply compute the corresponding character offset. In Ruby 1.8.7 multibyte chars are not supported by the lexer.

The lexer has conditional logic on `multibyte?` and makes a faster computation involving only 
positions on Ruby 1.8.7. On Ruby 1.9 it uses String.byteslice to produce a string for two given offsets. It can then compute the offset measured in characters, as well as the length of the string.

For Ruby 2.0, this can be optimized since the Stringscanner supports character position information.
In that case the character position instead of the byte position should be recorded, and the cheaper computation (using only positions) can be made.

Unless character position information is backported to Ruby 1.9, it is difficult to
optimize these operations. Not supporting multibyte is an option (which means lexer thinks it is reading non multibyte strings, and positions will be wrong if multibyte chars are present.

### Avoiding conditional logic

It is wasteful to have logic that is conditional on `mulitbyte?`, the lexer should instead configure itself at the start with methods that only does what is required (given a particular ruby version, possibly file encoding, etc.).

Munge
---
Munge does things like this:

        token, value = token.convert(self, value) if token.respond_to?(:convert)

This means it needs to make a call to see if it should make a call. It would be better to
always call a method.

A solution here, to avoid the tricky guards and blocks with convert logic would be to
subclass Token for the small number of tokens that need special handling (now they are special
in that calls have to be made to set them up with Procs etc.
