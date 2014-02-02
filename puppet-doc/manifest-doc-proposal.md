# Puppet documentation proposal
This is a proposal of how documentation could be written in puppet manifests


    # Internal comment (Not picked up by the doc generator)
    ## Documetantion
    /** Documentation */
    @example
    @param
    @deprecation
    @see
    @todo
    @api private | public
    @since version
    @return

### Examples


    /** Monitor a specific process in the system.
      Alert users if threshold is met
    */

    define monitor(
      $process, ## Name of process
      $memory_limit = '502' ## Memory limit in MB
      $alert = ['root'] ## Array of users to report to
      ) {
        # Do stuff
        $a = 'foo' ## This is picked up
        $b = 'bar' # This is not

        ## x is a nice variable
        $x = true

        ## @todo make it more robust
        $z = false
    }


Longer documentation

    /**
    This will monitor your system!
    @param memory [String] will default to 512, blah blah blah
    @param alert [Array] can take multiple people
    */

    monitor { 'foobar':
      memory_limit => 1024,
      alert => ['jhaals']
    }


_"This class is so easy so I'll skip writing doc"_
(Should generate documentation for the class, parameters and default values)

    class { 'foobar':
      backup => true
    }

## Invalid examples

parameter documentation should not be defined in two places. Output warning and skip

    define foo(
      ## should be ipv4
      $ip ## or ipv6
    )


Parameter documented both top and inline should warn and probably skip inline in favour for top doc

    ## This part handle the databases
    ## @params backup [Bool] wall of text

    database { 'mydb':
      ## Should probably backup by default
      backup => false
    }
