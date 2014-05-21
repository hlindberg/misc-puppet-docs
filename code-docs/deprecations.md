Deprecations
===
Deprecations are performed by calling `Puppet.deprecation_warning(msg)`. This in turn
will issue a warning if the deprecation is considered unique.

The uniqueness is determined by looking at the call stack and figuring out who called
the Puppet.deprecation_warning method. The entry as obtained by getting an entry from
caller is used as a key in global hash called `$deprecation_warnings`.
The message is kept in the hash.

If there are more than 100 entries in the $deprecation_warnings hash, then deprecations
are completely muted (they are lost).

Issues
---
While the deprecation system works reasonably well for deprecation of internal APIs, it does not really work well for deprecation of constructs in the PuppetProgramming Language, or for many different kinds of deprecations coming from the same source, but with different messages.

The cap of a 100 deprecations can happen quickly. If the master is up an running for a long
time, the deprecations may be buried deep in a log file. There is currently nothing clearing
the deprecation warnings.

### Agent Side Deprecations

Agent side deprecations are hard to handle. TODO: Why?

### Deprecating Settings

Deprecating settings is hard. TODO: Why?


Suggested Changes
---
The deprecation_warning method currently only takes a message, and it computes the offender identifier. This method could be given an optional options-hash where offender can be set.

The expected offender data type (currently) is an array, its entries are joined with '; ' when displayed
in the warning. Suggest that when offender is given as an option, it is wrapped in an array
by deprecation_warning (thus not really joining anything).



