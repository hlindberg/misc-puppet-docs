Fixing the Mixed Metaphors
===
In Puppet 3.4 there will be a new version of the future. More specifically a new version of the future parser that again brings the Puppet Language a little bit closer to Puppet 4.

Iterative Functions
---
One of the changes is a fix of the mixed metaphors in the iterative functions. It turned out that *"We did not have all our ducks on the same page"* [sic] as we had mixed the names of the functions from two different schools.

Here are the final iterative functions:

* `each` - no change
* `map` - was earlier called `collect`
* `reduce` - no change
* `filter` - was earlier called `select`
* `reject` - dropped
* `slice` - no change

Like any mixed metaphor this stuck out as a *sore throat you would not want to touch with a
10 foot pole, so we have been burning the midnight oil from both ends to get this fixed* [sic].
Sorry about the inconvenience this may cause regarding renaming - the functionality is the same though, so it should be easy to change.

Here are some examples to illustrate their use

    [1,2,3,4].each |$item| { notice $item }
    # Result: notice 1, notice 2, notice 3, notice 4

    [1,2,3,4].filter |$item| { $item % 2 == 0 }
    # Result: [2, 4]
    
    [1,2,3,4].map |$item| { $item * 2 }
    # Result [2, 4, 6, 8]
    
    [1,2,3,4].reduce |$memo, $item| { $memo + $item }
    # Result: 10
    
    [1,2,3,4].slice(2) |$first, $second| { notice $first + $second }
    # Result: notice 3, notice 7

One Syntax
---
The other mixed metaphor in the future parser was intentional; it had support for three different syntax styles for calling the iterative functions.
The recommended style with parameters outside the braces, a Java-8 like style using an additional
arrow, and a Ruby like style with the parameters inside the braces.

Usability studies showed that the recommended syntax (as shown above) was also the preferred among the majority of test pilots. In Puppet 3.4 the alternative syntax styles have been removed.

Remember, *"There is light at the end of the Rainbow as the road towards the future unfolds"* - a Mixed Metaphor Cocktail best served chilled.

- henrik
