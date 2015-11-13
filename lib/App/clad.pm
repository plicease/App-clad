package App::clad;

use strict;
use warnings;
use 5.010;
use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );
use AnyEvent::Open3::Simple;
use Clustericious::Config;

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
    dry_run => 0,
    color   => 1,
    config  => $config,
  }, $class;
  
  local @ARGV = @_;
  
  GetOptions(
    'n'   => \$self->{dry_run},
    'a'   => sub { $self->{color} = 0 },
    'l=s' => \$self->{user},
    'help|h' => sub { pod2usage({ -verbose => 2}) },
    'version'      => sub {
      say STDERR 'App::clad version ', ($App::clad::VERSION // 'dev');
      exit 1;
    },
  ) || pod2usage(1);
  
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

sub config   { shift->{config}      }
sub dry_run  { shift->{dry_run}     }
sub color    { shift->{color}       }
sub clusters { shift->{clusters}    }
sub command  { shift->{command}     }
sub user     { shift->{user}        }

1;
