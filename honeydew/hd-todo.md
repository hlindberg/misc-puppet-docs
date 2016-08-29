Error Handling in Puppet
---

### Exception Handling

Not really needed for Puppet DSL when compiling a catalog, but absolutely needed when running code on the agent. Without this, all functions must return a special value in case of an error.

#### Special value

This can be achieved by using some type tricks. A function returning T promises to never fail. A function returning Error[T] promises to return T, or an Error. A use case where an error is not acceptable would fail with a type mismatch error e.g:

~~~
 function do_or_die() => Error[Integer] { if current_time() > 3 { fail('sorry')} else { 42 } }

 # This fails because $x is an integer
 Integer $x = do_or_die()
 
 # This works because $x accepts error
 Error[Integer] $x = do_or_die()
 if $x[error] {
   # handle error
 } else {
   # use the value
   $the_value = $x[value]
 }
~~~

This style can be combined using a 'and then' functional style. Each call in the chain skips
calling the body if the value is undef or an Error, until the very end where a call dealing with undef or an error will be called. 

~~~
 $x = try   |  | { do_or_die() }
    .then   |$x| { $x + 10 }
    .then   |$x| { $x + 20 }
    .catch  |$e| { notice( "An error occurred: $e - using default value 0"); 0 }
~~~

The functions `try`, and `then` returns Variant[Error, T], which means that regular logic can
also perform error checks:

~~~
 $x = try || { do_or_die() }
 if $x =~ Error {
   # handle error
 } else {
   # handle value
 }
~~~

##### Implementation

The implementation of this is simple. It requires:

* Adding an Error type to the type system
* Adding functions `try`, `then` and `catch`

#### Changing the language

The Puppet Language could support this directly. 

~~~
 try {
   do_or_die()
 } catch => $e {
   Error['issue_code'] : { 
     # do this...
   }
   Error[Any, Pattern[/error occurred/] : {
     # message contains 'error occurred'
   }
 } finally {
   # we always get here
 }
~~~

### Raising Errors

Currently errors are raised by calling the function `fail`. It should be improved to enable
I18N, and being able to identify errors.

Internally, there is a feature for 'issues'. We should either modify the fail function, ora
add a new function (e.g. `throw`) to take additional arguments.

~~~
 raise('ISSUE_CODE', "Message text with interpolation $x", {x => 'interpolated' })
~~~

Ideally, the issue codes are declared, and messages are stored separately to make translation
easier (no need to scan source code).

Thus, raise, is allowed to raise an Issue (a new type). Issues are produced by using
functions.

~~~
  raise mymodule::bad_stuff($x, $y)
~~~

The issue function creates an Issue - e.g.
~~~
  issue('code', 'message', { arg => value,...})
~~~

It is intended to be created inside functions in a module:

~~~
function mymodule::bad_stuff(Integer $expected, Integer $got) {
  issue('BAD_STUFF', "Message: expected $expected, got $got")
}
~~~

While not perfect, such a construct is much easier to give to translators, and later, when there
is I18N support switch between messages in different languages.






