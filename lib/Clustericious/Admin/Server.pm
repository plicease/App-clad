package Clustericious::Admin::Server;

use strict;
use warnings;
use 5.010;
use Sys::Hostname qw( hostname );

# ABSTRACT: Parallel SSH client server side code
# VERSION

=head1 SYNOPSIS

 % perldoc clad

=head1 DESCRIPTION

This module provides part of the implementation for the
L<clad> command.  See the L<clad> command for the public
interface.

=head1 SEE ALSO

=over 4

=item L<clad>

=back

=cut

# This is the implementation of the clad server.
#
#  - requires Perl 5.10
#  - it is pure perl capable 
#  - no non-core requirements as of 5.14
#  - single file implementation
#  - optionally uses YAML::XS IF available
#
# The idea is that if App::clad is properly installed
# on the remote end, "clad --server" can be used to
# invoke, and you get YAML encoded payload.  The YAML
# payload is preferred because it is easier to read
# when things go wrong.  If App::clad is NOT installed
# on the remote end, then you can take this pm file,
# append the payload as JSON after the __DATA__ section
# below and send the server and payload and feed it
# into perl on the remote end.

sub _decode
{
  my($fh) = @_;
  my $raw = do { local $/; <STDIN> };

  my $payload;

  if($raw =~ /^---/)
  {
    eval {
      require YAML::XS;
      $payload = YAML::XS::Load($raw);
    };
    if(my $yaml_error = $@)
    {
      say STDERR "Clad Server: side YAML Error:";
      say STDERR $yaml_error;
      say STDERR "payload:";
      say STDERR $raw;
      return;
    }
    print STDERR YAML::XS::Dump($payload) if $payload->{verbose};
  }
  else
  {
    eval {
      require JSON::PP;
      $payload = JSON::PP::decode_json($raw);
    };
    if(my $json_error = $@)
    {
      say STDERR "Clad Server: side YAML/JSON Error:";
      say STDERR $json_error;
      say STDERR "payload:";
      say STDERR $raw;
      return;
    }
    print JSON::PP::encode_json($payload) if $payload->{verbose};
  }
  
  $payload;
}

sub _server
{
  my $payload = _decode(@_) || return 2;
  
  # Payload:
  #
  #   command: required, must be a array with at least one element
  #     the command to execute
  #
  #   env: optional, must be a hash reference
  #     any environmental overrides
  #
  #   verbose: optional true/false
  #     print out extra diagnostics
  #
  #   version: required number or 'dev'
  #     the client version
  #
  #   require: optional, number or 'dev'
  #     specifies the minimum required server
  #     server should die if requirement isn't met
  #     ignored if set to 'dev'
  #

  if(ref $payload->{command} ne 'ARRAY' || @{ $payload->{command} } == 0)
  {
    say STDERR "Clad Server: Unable to find command";
    return 2;
  }
  
  if(defined $payload->{env} && ref $payload->{env} ne 'HASH')
  {
    say STDERR "Clad Server: env is not hash";
    return 2;
  }
  
  unless($payload->{version})
  {
    say STDERR "Clad Server: no client version";
    return 2;
  }
  
  if($payload->{require} && defined $App::clad::VERSION)
  {
    if($payload->{require} ne 'dev' && $payload->{require} > $App::clad::VERSION)
    {
      say STDERR "Clad Server: client requested version @{[ $payload->{require} ]} but this is only $App::clad::VERSION";
      return 2;
    }
  }
  
  $ENV{$_} = $payload->{env}->{$_} for keys %{ $payload->{env} };
  
  system @{ $payload->{command} };
  
  if($? == -1)
  {
    say STDERR "Clad Server: failed to execute on @{[ hostname ]}";
    return 2;
  }
  elsif($? & 127)
  {
    say STDERR "Clad Server: died with signal @{[ $? & 127 ]} on @{[ hostname ]}";
    return 2;
  }
  
  return $? >> 8;
}

_server(*DATA) unless caller;

1;

__DATA__
