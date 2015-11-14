# clad

Parallel SSH client

# SYNOPSIS

    clad [-n] [-a] [-l user] <cluster> <command>

# DESCRIPTION

Clad provides the ability to run the same command on several hosts at 
once.  The output is displayed unbuffered as the various hosts run the 
command.  The list of hosts is determined by reading a configuration file
which may also contain command aliases and environment settings.

The command(s) will be executed under '/bin/sh -e' regardless of the 
login shell for the remote user.

# OPTIONS

- -n

    Dry run, just show the command that would be executed and each host.

- -a

    Do not colorize the host names in the output.

- -l user

    Specify a login name for all ssh connections.

- --verbose

    Print out a lot of debugging information which may be useful in debugging issues with clad.

- --serial

    Force clad to wait for the command to finish on each host before continuing to the next.  This
    will be slower, but may be easier to read the output.

- --help

    Print help and exit.

- --version

    Print the version and exit.

# ENVIRONMENT

## CLAD\_CLUSTER

This environment variable is set to the cluster name from the 
configuration file on each node that the command is run.  The deprecated
`CLUSTER` is also set, though that may be removed in a future version.

# AUTHOR

Graham Ollis &lt;plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
