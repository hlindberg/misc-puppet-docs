Run Agent and Master from source on same machine
===

````
bundle exec puppet master --no-daemonize --certname localhost --dns_alt_names localhost --verbose
bundle exec puppet agent -t --certname localhost --server localhost
````

To re-set the CSR process for an agent:

````
on the master: puppet cert clean <agent fqdn>
on the agent: remove the ssldir
````

Compile Catalog and get json output
===

````
bundle exec puppet master --no-daemonize --compile foonode --manifest foo.pp
````
