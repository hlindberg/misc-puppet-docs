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

Testing the Assumptions
---
Nothing ever turn out as expected!

A new implementation was made where three distinct and specialized implementation were made for Ruby18, Ruby19 and Ruby20. The Ruby20 impl use bsearch, and asked for the character position from the scanner using char_pos.

Since Ruby20 Array.bsearch returns the value and not the index, an additional structure
was needed to map found offset to line number.

The first result showed that the Ruby20 was faster, but not much. The Ruby18 implementation was almost 2x as slow (6.4 sec vs 11.1).

### Using a bsearch in ruby

A bsearch in ruby was then added. This implementation is specialized to search the line index, and returns the index instead of the value.

This speeded up the Ruby18 and Ruby19 implementations. In fact, they were now faster than the Ruby20 with a C implementation of bsearch. This probably because of the additional structure + the fact that it requires a block to be passed, and the block to be called for each value.

When switching also the Ruby20 implementation to using the special bsearch is was again at par with Ruby19. (Ruby18 reduced time from 11.1 to 9.7sec).

### Using scanner.charpos vs scanner.pos + bytslice

The scanner.charpos does not do a great job. The implementation using byteslice and offsets
is actually faster (Ruby20 went from 5.6 sec to 5.2 sec when using the implementation for Ruby19).

### Avoiding calculation

Avoiding calculation of detailed positions, and instead pass the Locator in the token's value hash
reduced the time about 12%. The "position in source" calls where also changes as an extra hash merge
was performed instead of passing the value to the function producing the hash with location information. (Now called `positioned_value`) - it now takes 1.93% of the time spent in the lexer
as opposed to 10-15%.

New Profiling
---
Profiling again still shows `scan` as the most expensive (32% / 22% in self), followed by `munge_token` (14% / 6.82% in self), followed by find_token, `find_string_token`, and `find_regexp_token` (these will vary depending on what is being lexed).

Additional Optimizations
---
### Comments
Comments are post processed and then skipped. Single line comments are ripped of
the leading '#', and Multiline comments are ripped of the enclosing /* */.

Since the text is never used, comments can just be tossed.

### Deprecated constructs

Dashed variables are no longer supported. Since all regular expressions are visited before
the string tokens are visited, the additional two tokens' regular expressions were always
matched (for every token!)

This gave the lexer an 11% boost 

Lessons Learned
---
### Calling a method is expensive
Using an accessor to access a instance variable is 5% more expensive that referencing it directly
in Ruby20 (1.05 vs 1.11), and it is 40% !!! more expensive in Ruby19 (0.88 vs 1.30)

### Hash lookup is faster than instance var
It is faster to lookup a symbol in a hash that it is to lookup an instance variable.
In Ruby19 0.78 vs 0.88, and in Ruby20 0.80 vs 1.05. Thus when more than one instance variable
is used in a method it may be beneficial to instead storing them in a hash.

The lexer has a `lexing_context` hash that is heavily used - and the thesis was that it may be faster to access individual instance variables. But this proved wrong. Instead, the best sequence may be
to assign the instance variable to a local variable, and then do hash lookups on it.

A quick test revealed that local variable assignment and dereference is a fraction more expensive,
but are both faster than using an accessor. (This test may be different if there are other local
variables, as initialization of a local scope may depend on there being variables or not. (Yes, if
scope has other variables, the method of assigning to a local variable is 10% faster on access 3 times).

By changing the scan method and using local variables for instance variables used multiple time
an additional speedup was gained. 5.45 vs 5.05.

### Inline regexp is faster than looked up

It is faster to use an inline regular expression than one that is assigned to a constant.
The difference in Ruby 2.0 is about 2%. In Ruby19 there is no difference. (Ruby20 is also 30% slower than Ruby 19).

     Benchmark.measure {1000000.times { '0xffe' =~ /^0[xX][0-9A-Fa-f]+$/ }}

Vary with pattern assigned to a variable and to a CONST.

Lexer 2
===
After running out of obvious optimizations using the current lexer's structure it was time to try
something else. How long would it take to rewrite the lexer using a conventional approach (sort
of hand writing the typical output from a lexer generator)?

It turned out not to take too long. After about 4 hours of Saturday coding everything except double
quoted strings and interpolation worked. An additional 4 hours on Sunday, simplified and optimized
interpolation also started to work.


Is it any faster?
---

### The revised test

The test was too simple as it had all the code on one line. Since a big drain on
performance is keeping track of detailed positioning the same test was modified to
contain new lines.

    lexer = Puppet::Pops::Parser::Lexer.new
    code = 'if true \n{\n 10 + 10\n }\n else\n {\n "interpolate ${foo} and stuff"\n }\n'
    10000.times {lexer.string = code; lexer.fullscan }


| Lexer                     | time (s) | normalized | factor (x)
| -----                     | ----     | ---        | ---
| Original Lexer            | 4.45     | 100        | 1
| Future Parser Unoptimized | 6.13     | 138        | 0.7
| Future Parser Optimized   | 4.52     | 101        | 1
| Lexer2                    | 1.3      | 29         | 3.4

On Ruby 2.0.0 there is a slight improvement in favor of Lexer2 (closer to 1.2 in average).

On Ruby 1.8.7 the difference is much less

| Lexer                     | time (s) | normalized | factor (x)
| -----                     | ----     | ---        | ---
| Original Lexer            | 7.7      | 100        | 1
| Lexer2                    | 6.3      | 82         | 1.22

