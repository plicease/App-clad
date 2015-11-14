# clad

Parallel SSH client

# SYNOPSIS

    clad [-n] [-a] [-l user] <cluster> <command>

# DESCRIPTION

Clad provides the ability to run the same command on several hosts at 
once.  The output is displayed unbuffered as the various hosts run the 
command.  The list of hosts is determined by reading a configuration file
which may also contain command aliases and environment settings.

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

- --config name

    Specify the name of an alternate configuration.  For example if you use `--config MyClad` then
    the configuration file `~/etc/MyClad.conf` will be used instead of `~/etc/Clad.conf`.

- --help

    Print help and exit.

- --version

    Print the version and exit.

# CONFIGURATION

The configuration file is a [Clustericious::Config](https://metacpan.org/pod/Clustericious::Config) style configuration file.
See ["EXAMPLES"](#examples) for an example configuration. 
It contains these sections and configuration items:

## env

Environment hash to override environment variables on all hosts that run the command.

## clusters

Hash to define the clusters.  This is a hash of lists, where the keys are the cluster names
and the lists are the host names.  For example:

    ---
    clusters:
      mycluster:
        - host1
        - host2
      myothercluster:
        - host3
        - host4

## aliases

Hash of aliases.  This is a useful place to specify common shortcuts.  The values
in this hash may be either strings or lists, allowing you to use the list or scalar
form of system.

## server\_command

[clad](https://metacpan.org/pod/clad) runs on both the client and the server.  This specifies the command used to
communicate with the client on the server end.  Unless you are testing [clad](https://metacpan.org/pod/clad) you
probably won't need to change this.

## ssh\_command

This is the `ssh` command to use on the client side.  It is `ssh` by default.

## ssh\_options

These are the `ssh` options used when opening a connection to the server.  The default
may change as needed.

## colors

A list of colors as understood by [Term::ANSIColor](https://metacpan.org/pod/Term::ANSIColor) which are used in alteration
for each host to help separate the output visually.

# EXAMPLES

Here is an example configuration

    ---
    env:
      PATH: /home/starscream/perl5/bin:/usr/local/bin:/usr/bin:/bin
      PERL5LIB: /home/starscream/perl5/lib
    
    clusters:
      mailservers:
        - mail1
        - mail2
      webservers:
        - www1
        - www2
        - www3
      databases:
        - db1
        - db2
        - db3
        - db4
    
    aliases:
      config_init: git clone git1:/cm/config-$CLUSTER.git ~/etc
      config_update: cd ~/etc && git pull
      config_destory: rm -rf ~/etc

## uptime

To find the uptime of the mailservers:

    % clad webservers uptime
    [mail1 out ]  21:27:04 up 4 days, 12:22,  0 users,  load average: 0.96, 1.01, 1.04
    [mail2 out ]  21:24:09 up 93 days, 12:52,  0 users,  load average: 1.25, 1.33, 1.29

To find the uptime of all servers in any cluster:

    % clad mailservers,webservers,databases
    [mail1 out ]  21:27:04 up 4 days, 12:22,  0 users,  load average: 0.96, 1.01, 1.04
    [mail2 out ]  21:24:09 up 93 days, 12:52,  0 users,  load average: 1.25, 1.33, 1.29
    [www1  out ]  21:24:37 up 93 days, 12:52,  0 users,  load average: 2.60, 2.34, 2.21
    [www2  out ]  21:23:06 up 93 days, 12:51,  0 users,  load average: 0.60, 0.50, 0.50
    [www3  out ]  21:24:05 up 93 days, 12:52,  0 users,  load average: 3.99, 3.62, 3.55
    [db1   out ]  21:24:53 up 93 days, 12:47,  0 users,  load average: 11.71, 12.15, 12.23
    [db2   out ]  21:26:07 up 93 days, 12:52,  0 users,  load average: 14.13, 13.91, 13.05
    [db3   out ]  21:29:06 up 93 days, 12:53,  0 users,  load average: 1.99, 1.59, 1.14
    [db4   out ]  21:24:55 up 93 days, 12:48,  0 users,  load average: 4.99, 4.83, 4.03

(note that the output in this example is displayed in order, though in practice it will usually be jumbled 

## log into hosts with different user

By default [clad](https://metacpan.org/pod/clad) will login to the remote servers with what ever user is default for `ssh`
(this is usually determined by the local user and / or the ssh configuration).  You can
use the `-l` option to specify a user name for all clusters in the command

    % clad -l foo mailservers,webservers,databases whoami
    [mail1 out ] foo
    [mail2 out ] foo
    [www1  out ] foo
    [www2  out ] foo
    [www3  out ] foo
    [db1   out ] foo
    [db2   out ] foo
    [db3   out ] foo
    [db4   out ] foo

or you can prefix individual clusters with a user name using the `@` sign.

    % clad foo@mailservers,bar@webservers,baz@database whoami
    [mail1 out ] foo
    [mail2 out ] foo
    [www1  out ] bar
    [www2  out ] bar
    [www3  out ] bar
    [db1   out ] baz
    [db2   out ] baz
    [db3   out ] baz
    [db4   out ] baz

## running Perl remotely

In the configuration above, we have specified `PATH` and `PERL5LIB` environment variables
to work with the modules build for [local::lib](https://metacpan.org/pod/local::lib) on each host (the actual configuration is
probably a little more complicated), so we can use modules that we have installed in
[local::lib](https://metacpan.org/pod/local::lib).

    % clad webservers -- perl -Mojo -E 'say g("mojolicio.us")->dom->at("title")->text'
    [www1 out ]
    [www1 out ]       Mojolicious - Perl real-time web framework
    [www1 out ]
    [www2 out ]
    [www2 out ]       Mojolicious - Perl real-time web framework
    [www2 out ]
    [www3 out ]
    [www3 out ]       Mojolicious - Perl real-time web framework
    [www3 out ]

## pulling remote configuration using git

[Clustericious](https://metacpan.org/pod/Clustericious) servers and client use configuration files that are usually stored in `~/etc`.
We usually manage these configurations on a cluster by cluster basis using git, and deploy
them using [clad](https://metacpan.org/pod/clad).

For example, to initialize the configuration directory using the &lt;config\_init> alias:

    ---
    aliases:
      config_init: git clone git1:/cm/config-$CLUSTER.git ~/etc

and run:

    % clad webservers config_init

...we can update using the `config_update` alias:

    ---
    aliases:
      config_update: cd ~/etc && git pull

and run:

    % clad webservers config_update

...and if the configuration becomes hosed, we can remove it and start over.
Since the master configuration is stored in git this may not be disaster.

    ---
    aliases:
      config_destory: rm -rf ~/etc

and run:

    % clad webservers config_destroy

## using shell

[clad](https://metacpan.org/pod/clad) runs the command on the remote end using the same exact arguments as
you pass it on the client side.  That means that it uses either the single
argument or list version of `system` depending on input.  That means that
if you want to use shell logic, pipes or redirection, you need to use the
single argument version!  For example:

    % clad webservers cd ~/etc && git pull    # WRONG !
    % clad webservers 'cd ~/etc && git pull'  # RIGHT !

Sometimes if you don't want to worry about the escaping of meta characters
the list version will be more appropriate

    % clad webservers perl -E 'say "hi there"'

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
