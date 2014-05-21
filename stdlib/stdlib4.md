Stdlib
===
The puppetlabs-stdlib module has been a place that has accumulated a lot of functionality
since its creation. Many of the functions have a long history, and not all of them are well behaved.

For Puppet 4 it is time to make a major overhaul.

### abs(n)

Useful. Based on the fact that 3x numbers are strings, but it also operates on Integers
and Floats since those are produced by expressions. It does not handle hex/octal strings.

Should change to not accepts strings. If a string should be interpreted as a number it
should be transformed with the new [value_of] function.

    abs(Integer.value_of("-123"))
    abs(Integer.value_of("c0de", {radix => 16}))

[value_of]: #value_of

### any2array()

Remove. This is replaced by the splat operator. 

| 3x                   | 4x  |
| ---                  | ---
| `$x = any2array($a)` | `$x = *$a `

### base64(Enum[encode, decode] action, String s)

Useful. Should raise ArgumentError, and not Puppet::ParseError though since it does not
know where in source it is.

### bool2num(Variant[Boolean, String]

Tries to be helpful but has odd corner cases.

    "undef", "undefined", "" => false
    "00"  => true
    "0"   => false
    "0x0" => false
    "-1"  => error
    "-0"  => error
    "t"   => true
    "T"   => error
    0     => error (does not handle numeric input)
    
The new value_of functions does not have this swiss army knife behavior, it translate
the strings "true" and "false" to Boolean.

Tis function is useful for users that really need a numeric 0 or 1, and that
do not want to rite the corresponding transformation as a case expression in
puppet. With puppet functions it would look like this:

    function bool2num(Optional[Variant[Boolean, String, Numeric]] $value) {
      case $value {
        undef, false, "0", f, no, "false" : { 0 }
        true, "true", yes, t, "1"         : { 1 }
        Integer[default, 0]               : { 0 } # negative values are false
        Float[default, 0.0]               : { 0 }
        Integer, Float                    : { 1 } # positive are true
      }
    }

Suggest removing in favor of users writing their own (which they can then
even internationalize).

### bool2str(Boolean $value)

Odd. This function asserts that the value is a Boolean and transforms it into a string.

Suggest removing. 

| 3x                   | 4x  | comment
| ---                  | --- | ---
| `$x = bool2str($a)` | `$x = "${Boolean.assert_type($a)}"` |  with assertion
| `$x = bool2str($a)` | `$x = "$a"`                         |  without

### camelcase(Variant[Array, String] $value)

Useful, but has corner cases. If given an array where some entries are not strings, then
they are simply skipped. (It should raise an error).

* There is no `decamelcase` function.
* Does not work for international characters

### capitalize(Variant[Array, String] $value)

Useful, capitalizes strings, skips all other kinds of data in arrays.

* It smells that it skips all other data types
* Does not work for international characters

### chomp(Variant[Array, String] $value)

Somewhat Useful, chomps the record separator (which includes more than
what is shown in the doc for the function).

* Bad that the separator relies on what is configured in Ruby - it should be
  a fixed value, or user should be given the opportunity to pass a second argument for
  record separator.
* It smells that it skips all other data types than strings (like nested arrays with strings)
* The same can be achieved with regsubst, or simply a regular expression match with capture 
 
### concat(Array $a, Optional[Object] $b)

**BAD!** Mutates the array $a! when b is an array, returns copy of a with $b appended
otherwise.

REMOVE.

| 3x                      | 4x  | comment
| ---                     | --- | ---
| `$x = concat($a, $b)`   | `$x = $a + $b`                    |  safe concat / append
| `$x = concat($a, [$b])` | `$x = $a << $b`                   |  append

### count(Collection $a, Optional[Object] $item = Variant[Type, Object])

Useful. Counts number of elements that match item, or that are no undef/nil if no item
is given. Has some issues though.

* Could be extended to support a lambda (as predicate function)
* Uses ruby semantics for comparing elements against each value which means case significant
  string comparison, comparison against number/string etc. does not work

* Should change to use evaluator comparison for non block $item

### deep_merge(Hash $a, Hash $b)

Useful, has issues and is far less versatile than the deep merge gem that is used in hiera.
Has implementation issues:

* function is recursive and may run out of stack if hashes are big
* inefficient

For anyone that i serious about merging hashes in a deep way, the deep_merge gem
is required. Suggest reimplementing based on that.

REWRITE.

### defined_with_params(String $ref, Hash $param_map)

Can be replaced with puppet logic since it is possible to get the parameter values
from defined resources. The function offers no additional functionality (it too is evaluation
order dependent, does not lookup default values, and does not handle meta parameter defaults).

REMOVE.

| 3x                      | 4x  
| ---                     | --- 
| `defined_with_parameters(User[dan], {ensure => present}`   | `User[dan][ensure] == present`

For multiple values, use new iterative function [all], or other iterative function (filter, map,
reduce) depending on what is wanted as the end result). 

    $param_map.all |$k, $v| { User[dan][$k] == $v }

[all]: #all

### delete(Variant[String, Array, Hash] $value, Optional[Object] $item)

Replaced by - operator on `Array` and `Hash`.
Use `regexpsubst` for `String`.

REMOVE.

* Has problems since the comparisson semantics are not the same for Ruby and Puppet
* Name suggest it is a mutating operation


### delete_at(Variant[String, Array, Hash] $value, Variant[String, Numeric] $item)

Replaced by iterative function filter (filter based on index or key), or getting a consecutive
range using from, to index (and then concatenating the result).

REMOVE.

* Has problems with numeric strings (does not handle all cases)
* Can not delete the last element (negative values not supported)

### delete_undef_values(Collection $values, ...)

* Removes undef values (but not nil)
* Accepts any number of arguments, but ignores all but the first
* Only removes surface level undef
* Does not remove undef keys in a hash

Questionable value, needs to be rewritten if the intent is to remove nil's and not
just getting rid of the :undef entries.

### delete_values(Hash $h, $item)

Replaced by iterative function `filter`.

REMOVE.

* Uses wrong comparison semantics (Ruby).

### difference(Array $a, Array $b)

Replaced by - operator (which also supports hash key diff)

REMOVE.

* Uses wrong comparison semantics (Ruby)

### dirname(String path)

Useful. returns the dirname of a path.

* Uses File.dirname, should use the Puppet File abstraction

### downcase(String s)

Useful.

* Does not handle international characters
* iterates over an array, and skips entries that are not string, should error
* Questionable if it should have iterative powers at all

### empty(Variant[String, Collection] $a)

Useful. Can also be done by using type with size constraint (since empty this is
an additional validation step it can be avoided when testing against type + size at the same
time). Also questionable, since there is a size function.

Documentation is off, it says it checks a variable (it does not, it checks the
argument).

KEEP

* fix documentation
* consider other types to be not empty except undef ? (questionable)

### ensure_packages

* Debatable if it should survive
* Is a statement type function, should be changed to r-value and return something useful (like
  packages not already included as Package[] references.
  
### ensure_resource

* Debatable if it should survive 
* it is a statement type function, should be changed to return Resource type instance

### flatten(Array $a)

Useful. Does not support specifying depth.

### floor(Numeric $value)

Useful.

* Only works on Numeric in numeric form.
* Their is no `ceil` function (round up)

### fqdn_rotate(?)

Probably useful, is it enough / is it too simple?
(Not fully reviewed, seems somewhat too specialized for stdlib).

### get_module_path(String $module_name)

Useful for digging out random files from a module, but questionable why that is needed.
Has potential issues with "current environment" since it used environment by name from the
compiler.

Explore use cases. Should this be supported a different way? What if modules
are not layer out on the file system at some point? Is this a kind of load file content
base functionality?

### get_param(String ref, String param_name)

Replaced by operators that get the parameter value of a resource. Offers no
additional functionality.

REMOVE.

### get_var(String ref)

Somewhat useful. It allows dynamic reference to a variable in another class.

* Will need to change when scope implementation changes.
* Should perhaps be implemented via Class[name][var] since parameters of a class
  can be accessed that way, but not its other attributes. (Using variables is an odd choice
  to begin with, these variables are no different than resource parameters).

Suggest fixing the language, and removing this function.

### grep(Object, Object)

Has several issues and is replaced by iterative functions.

REMOVE.

* Blindly searches in first argument
* Blindly constructs a Regexp of the second argument
* Calls Ruby grep on the first argument
* Will fail on non string content

### has_interface_with, has_ip_address, has_ip_network

Useful, Has issues

* It looks up the variable 'interfaces'
* It checks if the value is :undefined 
* It looks up child interfaces as variables

With the introduction of structured facts, and facts in a hash, this is now much easier.

Suggest Removing.

### has_key(Hash $h, Object $k)

Useful. Keep

### hash(Array $a)

Useful, should be replaced by `Hash.value_of($a)` to unify all type transformations.

### intersection(Array $a, Array $b)

Useful. Should be extended to also intersect Hashes based on key.

### is_xxx type tests

Almost all of the type testing functions can be removed in favor of the type system.
Some of these have the ability to check if the value is the type in string form (but
does not do it the same way as the lexer/parser). If it is of value to test converting
them, it is best to give value_of the ability to return undef instead of a raising
an error - e.g. `Integer.value_of("0791", {radix => 8, rescue => true })`.

* is_array
* is_bool
* is_float
* is_hash
* is_integer
* is_numeric
* is_string


### is_function_available

Replace with `&funcname` (results is `undef` if not available)

### is_domain_name

Useful.

### is_ip_address

Useful.

### is_mac_address

Useful

### join(Array, String separator='')

Useful.

* Has somewhat strange wording in errors

### join_keys_to_values(Hash $h, String separator)

Not very useful, lacks in versatility. Can be achieved with iterative function `map`

REMOVE.

### keys(Hash $h)

Useful. Can be achieved with an iterative map function too. Suggest keeping.

### loadyaml(String path)

File IO function.

* Is this safe?
* No guarantee what is returned
* No symbolic handling of content

If the purpose is to simply check the syntax, there is an [assert_syntax] function
for that supporting plugins that asserts the syntax.

[assert_syntax]: #assert_syntax

### lstrip

Can be achieved with a regexp and iterative functions.

* Uncertain what Ruby "whitespace" means here, does it support all kinds of :blank: ?

Needs investigation.

### max(Variant[String, Numeric] $a, Variant[String, Numeric] $b)

Useful, but should fail if given a string. Does some string to numeric conversion,
but not the same as the lexer/parser. Does to handle floats in scientific notation,
not hex and not octal.

This is actually not a max function - it returns the comparison result !

Replace with a math max.
The min function has the same issues.


### min(Variant[String, Numeric] $a, Variant[String, Numeric] $b)

Useful but has same issues as max.

Replace with math min.

### member

Replaced by correct evaluation of the `in` expression, or by iterative functions.

REMOVE

* does not use puppet semantics

### merge

Replaced by operator + on hashes. There is also a deep_merge function that is more
versatile.

REMOVE (or if desired, simply call evaluator to do this from the function).
Has iterative powers too - replace by iterating over collection.

### num2bool(Variant[String, Numeric] $value)

Useful.

Tries to convert numerics in string form, but does not handle all cases since it transforms
to a Float, and fails, does not handle octal and hex values in string form.

Suggest correcting.

### parsejson, parseyaml

Performs File IO.
Loads data without checking what the result is.
Duplicate implementation in loadyaml.

Is these for parsing, or actually loading data?

### pick

Replaced by new iterative function [find]. Although pick is generic, its documentation
suggests it is for use with Dashboard. Has duplicate better implementation called pick_default.

REMOVE

[find]: #find

### pick_default
Better implementation of `pick`.
Can be replaced by generic iterative function [find], or simple logic like

    $value = if $test == undef { '1.234' } else { $test }
    $value ? $test ? { undef => '1.234', default => $test }

Also, since strict variables may be on by default in the future, it is not possible
to get an undef variable - it is an error. Instead, a check is needed if a variable
is defined. The class type syntax Class[name][param_or_var] may be used and return
undef if not set.

Or by using a hash of default values, and iterating if this is done for multiple 
variables.

Suggest keeping since it is somewhat hotter in most cases, and it does not 
do anything bad.

### prefix

Replaced by general iterative functions (map).

REMOVE

### range

Both bad and useful. Creates a new array filled with values. Has issues with numeric
arguments in string form. Ranges written as strings.
Can be replaced with iterating of an Integer range or iterating using map to create
strings etc.

Suggest removing.

### reject

Replaced by general purpose filter iterative function, and operator - (delete key)

REMOVE.

### reverse(Variant[Array, String] $value)

Useful. Keep.

### rstrip

See lstrip

### shuffle

Not sure of use cases. Seems useful if you need this sort of thing. Kind of specialized though...

Is this for crypto/digest functionality?

### size

Useful. Keep.

* Should also handle size of an Integer or Float range

### sort

Useful. Keep

Should allow a block to be used to define the order
Should probably use puppet semantics for defining the order

### squeeze

Have never had to use such a function. Seems useful if you have the exact problem.
Kind of specialized though.

(Squeezes multiple identical characters into a single character).

On the fence. Put in some other module?


### str2bool

This is almost the same as bool2num, but returns Boolean instead of numeric 0 / 1.

Treats empty string as false

Decide in conjunction with bool2num if these should be kept and updated.

### str22saltedsha512

Probably useful. Kind of specialized. (Place all the crypto like digest stuff in one
separate module?)

### strftime

Useful. keep

### strip

See lstrip, rstrip

### suffix

See prefix.
REMOVE

### swapcase

Does not seem very useful. Does not support international characters.
REMOVE.

### time(String $tz = "")

Useful. Keep. Improve documentation.

### to_bytes(String $size_with_unit)

Useful. Keep. The name is somewhat strange as it suggests turning a string into
an array of byte values.

Is also not 100% correct when used with disk sizes since M and G are not based on 1024, but 1000.
Ok for primary memory and byte calculations in general.

Suggest:
* name change
* possibly have two functions (one for disk and one for memory)
* accepting 1 or two args value, unit, if one given is string form, unit is alway string form
* does not accept float with 'E', (only 'e').


### type

MEGA CLASH with new keyword "type". This is replaced by the [type_of] function, that returns
a type instance instead of a string. 

REMOVE.

### union(Array $a, Array $b)

Useful. Union of two arrays. Has problem since union is based on Ruby semantics.
Should be rewritten to use Puppet semantics.

    # problem illustration
    union([A], [a]) => [A, a]
    [A] == [a]      => true 


### unique(Variant[String, Array] $a)

Useful for Array. Removing duplicates from a String does not seem very useful - is
there a typical use case? If not, then regsubst can do the job instead. 

Uses Ruby semantics for comparisons, should be rewritten.

### upcase

Useful. Does not support international characters.

### uriescape(Varaint[String, Array[String] $a)

Useful.

* Has iterative power.
* Silently skips non strings (should error)
* Probably has a bug since it references a variable called "unsafe" that is not defined anywhere when given an Array to escape


### validate_absolute_path

Useful. It would be very good to reimplement the kinds of paths as types in the type system.
That enables specifying types like `Array[AbsolutePath]`.

Type types, Path, RelativePath, AbsolutePath, WindowsPath ?


### validate_auegas

Belongs in an auegas module.

### validate_cmd(String $content, String $cmd

Useful. but has issues.

* This is an assert function, it would be more useful if it returned the input.
* Suggest name change to assert_with_cmd.
* Requires cmd to be installed on machine
* Using the [assert_syntax] function makes it possible to plugin behavior in a modular way
* The validate_cmd can be used to execute any external script (TODO: Util::Execution may
  check validity of path, etc.)

Needs more investigation / thought.

### validate_ipv4_address

Useful.

* Has iterative power

Is a good candidate for a new Type in the type system IPV4.

### vaidate_ipv6_address

Useful.

* Has iterative power

Is a good candidate for a new Type in the type system IPV6

### validate_x where x is a type

These are all replaced by the Type system.

* validate_array
* validate_bool
* validate_hash
* validate_re
* validate_slength
* validate_string

REMOVE.

### values

Useful. Can also be done with general iteration (map).

Keep.

### values_at

Less useful since it is possible to get ranges, and use general iteration.

### zip

Useful. Has issues, as it is a swiss army knife.

* Uses magic translation to boolean for the flatten parameter (should not use flatten)
* Does not provide a way to give what to use for missing values in shorter array

REWRITE

New Functions
---
### all(Collection $x, Callable $block)

The puppet equivalence of Ruby's Enumerable.all?

### any(Collection $x, Callable $block)

The puppet equivalence of Ruby's Enumerable.any?

### assert_syntax

T.B.D (PUP-???)

### compare(Object $a, Object $b)

Same as the evaluators compare, returns -1, 0, or 1 depending on which of the
operands is bigger. Handles data types that can be compared.

See min / max as functions that tries to implement this (but fails).

### value_of(Type t, String value, Hash options)

Creates an instance of the given type from the given string. Each type accepts
different options (e.g. `Integer` accepts `radix` with a value of `8`, `10`, or `16`).

### type_of($x)

Returns a Type instance describing the type of the given argument. Uses the type
system and gives richer information than just a string.

[type_of]:#type_of

Function Categories
---

### Collections

* keys
* values
* size
* union
* intersect
* delete
* delete_at
* delete_undef_values (i.e. compact)
* join
* join_keys_to_values
* flatten
* empty
* concat
* merge
* count
* deep_merge
* difference
* has_key
* member
* pick (broken)
* pick_default (replacement)
* reject (not same as Ruby reject)
* sort

### String

* split
* upcase
* downcase
* shuffle
* swapcase
* capitalize
* camelcase
* chop
* chomp
* count
* squeeze
* size

### Math

* max
* min
* abs
* to_bytes
* floor
* (ceil - missing)

### Time

* strftime
* time

### Transformation

* base64
* bool2num
* bool2str
* any2array
* prefix
* suffix
* range
* str2bool

### Digests/Crypto

* ? fqdn_rotate

### IP

* validate_IPV4
* validate_IPV6
* has_ip_address
* has_ip_network
* has_interface_with

### Catalog

* ensure_resource
* ensure_package
* get_param
* defined_with_params

### IO

* loadyaml
* parse_yaml
* parse_json
* dirname

### Misc

* is_function_available

### Type

(not listed) - all the is_xxx, and validate_ that are replaced by the type system
