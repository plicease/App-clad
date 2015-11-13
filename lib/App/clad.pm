package App::clad;

use strict;
use warnings;
use 5.010;
use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );
use AE;
use AnyEvent::Open3::Simple 0.76;
use Clustericious::Config 1.03;
use YAML::XS qw( Dump Load );
use Term::ANSIColor ();
use Sys::Hostname qw( hostname );

# ABSTRACT: Parallel SSH client
# VERSION

=head1 SYNOPSIS

 % perldoc clad

=head1 DESCRIPTION

This module provides the implementation for the L<clad> command.  See 
the L<clad> command for the public interface.

=head1 SEE ALSO

=over 4

=item L<clad>

=back

=cut

sub main
{
  my $clad = shift->new(@_);
  $clad->run;
}

sub new
{
  my $class = shift;
  
  my $config = Clustericious::Config->new('Clad');
  
  my $self = bless {
    dry_run    => 0,
    color      => 1,
    config     => $config,
    server     => 0,
    verbose    => 0,
    next_color => -1,
  }, $class;
  
  local @ARGV = @_;
  
  GetOptions(
    'n'       => \$self->{dry_run},
    'a'       => sub { $self->{color} = 0 },
    'l=s'     => \$self->{user},
    'server'  => \$self->{server},
    'verbose' => \$self->{verbose},
    'help|h'  => sub { pod2usage({ -verbose => 2}) },
    'version' => sub {
      say STDERR 'App::clad version ', ($App::clad::VERSION // 'dev');
      exit 1;
    },
  ) || pod2usage(1);
  
  return $self if $self->server;
  
  pod2usage(1) unless @ARGV >= 2;
  
  $self->{clusters} = [ split ',', shift @ARGV ];
  $self->{command}  = [ @ARGV ];
  
  my $ok = 1;
  
  foreach my $cluster (map { "$_" } @{ $self->{clusters} })
  {
    $cluster =~ s/^.*@//;
    unless($self->config->clusters->{$cluster})
    {
      say STDERR "unknown cluster: $cluster";
      $ok = 0;
    }
  }
  
  exit 2 unless $ok;
  
  $self;
}

sub config         { shift->{config}      }
sub dry_run        { shift->{dry_run}     }
sub color          { shift->{color}       }
sub clusters       { shift->{clusters}    }
sub command        { shift->{command}     }
sub user           { shift->{user}        }
sub server         { shift->{server}      }
sub verbose        { shift->{verbose}     }
sub server_command { shift->config->server_command( default => 'clad --server' ) }
sub ssh_command    { shift->config->ssh_command(    default => 'ssh' ) }
sub ssh_options    { shift->config->ssh_options(    default => [ -o => 'StrictHostKeyChecking=no', 
                                                                 -o => 'BatchMode=yes',
                                                                 -o => 'PasswordAuthentication=no',
                                                                 '-T', ] ) }

#sub ac
#{
#  my($self, $color) = @_;
#  Term::ANSIColor::color($color) if $self->color;
#}

sub host_length
{
  my($self) = @_;

  unless($self->{host_length})
  {
    my $length = 0;
  
    foreach my $cluster (map { "$_" } @{ $self->{clusters} })
    {
      my $user = $cluster =~ s/^(.*)@// ? $1 : $self->user;
      foreach my $host (@{ $self->config->clusters->{$cluster} })
      {
        my $prefix = ($user ? "$user\@" : '') . $host;
        $length = length $prefix if length $prefix > $length;
      }
    }
    
    $self->{host_length} = $length;
  }
  
  $self->{host_length};
}

sub print_line
{
  my($self, $color, $prefix, $code, $line) = @_;
  
  print Term::ANSIColor::color($color) if $self->color;
  printf "[%@{[ $self->host_length ]}s %4s] ", $prefix, $code;
  print Term::ANSIColor::color('reset') if $self->color;
  print $line, "\n";
}

sub next_color
{
  my($self) = @_;
  my @colors = $self->config->colors( default => ['green','cyan'] );
  $colors[ ++$self->{next_color} ] // $colors[ $self->{next_color} = 0 ];
}

sub run
{
  my($self) = @_;
  
  return $self->run_server if $self->server;
  
  my $ret = 0;
  my @done;
  
  foreach my $cluster (map { "$_" } @{ $self->{clusters} })
  {
    my $user = $cluster =~ s/^(.*)@// ? $1 : $self->user;

    my %env = $self->config->env;
    $env{CLUSTER} //= $cluster;

    foreach my $host (@{ $self->config->clusters->{$cluster} })
    {
      my $prefix = ($user ? "$user\@" : '') . $host;
      if($self->dry_run)
      {
        say "$prefix % @{ $self->command }";
      }
      else
      {
        my $done = AE::cv;
        my $color;
        $color = 0 unless $self->color;
      
        my $ipc = AnyEvent::Open3::Simple->new(
          on_stdout => sub {
            my($proc, $line) = @_;
            $self->print_line(
              $color //= $self->next_color,
              $prefix,
              'out ',
              $line,
            );
          },
          on_stderr => sub {
            my($proc, $line) = @_;
            $self->print_line(
              $color //= $self->next_color,
              $prefix,
              'err ',
              $line,
            );
          },
          on_exit => sub {
            my($proc, $exit, $signal) = @_;
            $color //= $self->next_color;
            $self->print_line(
              $color,
              $prefix,
              'exit',
              "$exit",
            ) if $exit;
            $self->print_line(
              $color,
              $prefix,
              'sig',
              "$signal",
            ) if $signal;
            $ret = 2 if $exit || $signal;
            $done->send;
          },
          on_error => sub {
            my($error) = @_;
            $color //= $self->next_color;
            say "[$prefix fail] $error";
            $ret = 2;
            $done->send;
          },
        );

        my $payload = Dump({
          env     => \%env,
          command => $self->command,
          verbose => $self->verbose,
        });
        
        $ipc->run(
          $self->ssh_command, 
          @{ $self->ssh_options }, 
          ($user ? ('-l' => $user) : ()), 
          $host,
          $self->server_command,
          \$payload,
        );
        
        push @done, $done;
      }
    }
  }
  
  $_->recv for @done;
  
  $ret;
}

sub run_server
{
  my($self) = @_;
  
  my $input = Load(do { local $/; <STDIN> });
  
  print STDERR Dump($input) if $input->{verbose};
  
  $ENV{$_} = $input->{env}->{$_} for keys %{ $input->{env} };
  
  system @{ $input->{command} };
  
  if($? == -1)
  {
    say STDERR "failed to execute on @{[ hostname ]}";
    exit 2;
  }
  elsif($? & 127)
  {
    say STDERR "died with signal @{[ $? & 127 ]} on @{[ hostname ]}";
    exit 2;
  }
  
  exit $? >> 8;
}

1;
