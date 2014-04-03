Scope Stuffs
===

Node Scope
---
* People want access to node scope
* What is node scope vs. top scope
* What happens with shadowing when loaded code sets things in top scope

Access to Node Scope
---
For node scope to become addressable it needs to be in a namespace, and this namespace
is always the same (since users will reference things in "current node scope" (not for some
other node).

Alternatively, this can be available via a type. Node[name] could be a reference to a particular
node's scope. ThisNode could be a reference to the current evaluating node. The later could accept reference to its parameters - i.e. `ThisNode[msg]` would get $msg in nodescope.

We can also create a named scope, even setting of a variable in node scope (say $x) becomes
a setting in `$nodescope::x`, and this thus both shadowing and globally accessible.

Node Scope vs Top Scope
---

If autoloaded code has code in top scope - what should happen when a variable is set?

* It is set in top scope and potentially (already) shadowed in node scope
* It is set in node scope, and potentially clashes (mutation attempt error)
* node scope does not exist - a new top scope being a merge is set as the global scope (and 
  all top scope settings after that are clashes
  
We may also forbid all top scope assignments in auto loaded code.

Match Scope
---
A match scope is constructed based on a regular expression match. There is however a problem
in that a sequence of statements should retain the last match scope. For this reason,
scope must handle match result in a special way.

When a match is made, the match data should simply be set in scope. When entering an expression
that preserves the current match data, it should create a new MatchScope (transparent to everything
except match data).

Performance Improvements
---
Numeric variable detection is a performance problem, every lookup in every scope has to check
if the variable name is numeric. We can solve this by creating a special instruction
for numeric variables and have a special lookup of these via dedicated lookup / exists. This
then completely removes the need to look at the variable name string.

We can probably also speed up by differentiating between SimpleName, and QualifiedName. Thi
because we only have to check for '::' when it is constructed. We may also keep the value
around in both concatenated and split form to avoid having to split and combine it multiple
times.

Discussion
===

Node Scope is a transaction specific context around the logic being evaluated. If it shadows
there should really be no way to break out from that shadowing and read the non shadowed variables.
(i.e. no breaking of the encapsulation).

This means that all top scope assignments (if allowed) in autoloaded code should be set in
the node scope - i.e. there is no difference between it and the top scope and they could just as well be merged right away.
