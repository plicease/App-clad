# clad [![Build Status](https://secure.travis-ci.org/plicease/App-clad.png)](http://travis-ci.org/plicease/App-clad)

Parallel SSH client

# SYNOPSIS

    clad [options] <cluster> <command>
    clad --list
    clad --help

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

- --config _name_

    Specify the name of an alternate configuration.  For example if you use `--config MyClad` then
    the configuration file `~/etc/MyClad.conf` will be used instead of `~/etc/Clad.conf`.

- --fat

    Send the server code with the payload and feed into Perl on the remote end.  This makes
    the total payload much larger, but it allows you to use clad with servers that do not
    have [App::clad](https://metacpan.org/pod/App::clad) installed.  The remote end must have Perl 5.6.1 or better in the `PATH`.

- --max _number_

    Limit the maximum number of simultaneous connections to `number`

- --file _filename_

    Copy files to the remote end as part of the payload.  May be specified multiple times.
    The names of the files are available as environment variables `FILE1`, `FILE2`, etc.  The
    files will automatically be removed on the remote end when the command completes.  An example
    usage for this would be to install rpm packages:

        % clad --file Database-Server-0.01-1.noarch.rp mycluster 'rpm -U $FILE1'

- --dir _directory_

    Recursively copy the directory to the remote end as part of the payload.  The name of the directory
    is available as an environment variable `DIR`.  The directory will automatically be removed on
    the remote end when the command completes.  For example if you are installing a directory full of
    rpm packages:

        % clad --dir ~/rpmbuild/RPMS/noarch mycluster 'rpm -U $DIR/*'

- --summary

    Do not print out standard output and standard input, just the exit values or signals returned from
    each host.

- --log-dir _dir_

    Specify a directory to write log files to.  Each host will have its own log file.

- --log

    Same as `--log-dir`, but the location is ~/clad/log.

- --purge

    Purge any logs that have collected under your home directory from using the `--log` option.

- --list

    List the clusters and aliases defined in your configuration.

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

## cluster

Hash to define the clusters.  This is a hash of lists, where the keys are the cluster names
and the lists are the host names.  For example:

    ---
    cluster:
      mycluster:
        - host1
        - host2
      myothercluster:
        - host3
        - host4

You can use a single hostname not in the `cluster` section to specify a cluster
of one host, so long as it is a legal hostname understood by `ssh`.

## alias

Hash of aliases.  This is a useful place to specify common shortcuts.  The values
in this hash may be either strings or lists, allowing you to use the list or scalar
form of system.

## server\_command

[clad](https://metacpan.org/pod/clad) runs on both the client and the server.  This specifies the command used to
communicate with the client on the server end.  Unless you are testing [clad](https://metacpan.org/pod/clad) you
probably won't need to change this.

## fat

Include the server code as part of the payload.  This is useful for hosts that
do not already have [App::clad](https://metacpan.org/pod/App::clad) installed.  This is the same as the `--fat`
option above.

## fat\_server\_command

The command to execute on the server side when using the `--fat` command line
option or the `fat` configuration option.  The default is simply `perl`.

## ssh\_command

This is the `ssh` command to use on the client side.  It is `ssh` by default.

## ssh\_options

These are the `ssh` options used when opening a connection to the server.  The default
may change as needed.

## ssh\_extra

Extra ssh command line options to be added after `ssh_options`.  If you just want to
add a few options without replacing the existing set, this is the way to go.

## colors

A list of colors as understood by [Term::ANSIColor](https://metacpan.org/pod/Term::ANSIColor) which are used in alteration
for each host to help separate the output visually.

## fail\_color

Color to use if clad determined the remote call failed

- exit with non zero
- killed by signal
- failed to start (usually due to a bad command)

The default is `bold red`.

## err\_color

Color to use for output to standard error.  The default is `bold yellow`.

## script

A hash of inline scripts.  The keys are the script name and the values are the script
bodies.  For example, with

    ---
    script:
      dir_listing:
        #!/bin/bash
        for i in $( ls ); do
          echo item: $i
        done

You can get directory listing with

    % clad cluster dir_listing

# EXAMPLES

Here is an example configuration

    ---
    env:
      PATH: /home/starscream/perl5/bin:/usr/local/bin:/usr/bin:/bin
      PERL5LIB: /home/starscream/perl5/lib
    
    cluster:
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
    
    alias:
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
    alias:
      config_init: git clone git1:/cm/config-$CLUSTER.git ~/etc

and run:

    % clad webservers config_init

...we can update using the `config_update` alias:

    ---
    alias:
      config_update: cd ~/etc && git pull

and run:

    % clad webservers config_update

...and if the configuration becomes hosed, we can remove it and start over.
Since the master configuration is stored in git this may not be disaster.

    ---
    alias:
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
configuration file on each node that the command is run.

# INSTALL

You can override the default values for the `--fat`, `--server_command` and
`--fat_server_command` at install time using options to Build.PL.

    perl Build.PL --clad_fat \
                  --clad_server_command /usr/local/bin/perl \
                  --server_command /usr/local/bin/perl /usr/local/bin/clad --server

In this example, we specify fully qualified pathnames for Perl and [clad](https://metacpan.org/pod/clad), which
may be what you want in environments where the system Perl (usually installed in
`/usr/bin/perl`) comes before the Perl that you want to use.

# CAVEATS

[Clustericious::Admin](https://metacpan.org/pod/Clustericious::Admin) and [clad](https://metacpan.org/pod/clad) require an [AnyEvent](https://metacpan.org/pod/AnyEvent) event loop that allows
entering the event loop by calling `recv` on a condition variable.  This is not
supported by all [AnyEvent](https://metacpan.org/pod/AnyEvent) event loops and is discouraged by the [AnyEvent](https://metacpan.org/pod/AnyEvent)
documentation for CPAN modules, though most of the important event loops, such as
[EV](https://metacpan.org/pod/EV) and the pure perl implementation that comes with [AnyEvent](https://metacpan.org/pod/AnyEvent) DO support
this behavior.

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015-2019 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
