package Clustericious::Admin;

use strict;
use warnings;
use App::clad;
use Carp ();
use PerlX::Maybe qw( maybe );

# ABSTRACT: Parallel SSH client
# VERSION

=head1 SYNOPSIS

 % perldoc clad

=head1 DESCRIPTION

This module used to contain the machinery to implement the L<clad> command.
This was moved into L<App::clad> when it was rewritten.  This module is
provided for compatibility.  In the future it may provide a Perl level API
for L<clad>

=head1 SEE ALSO

=over 4

=item L<clad>

=back

=cut

sub banners
{
  (undef) = @_;
  Carp::carp "Class method call of Clustericious::Admin->banners is deprecated";
  ();
}

sub clusters
{
  my $self = shift;
  
  ref $self
  ? $self->SUPER::new($_)
  : do {
    Carp::carp "Class method call of Clustericious::Admin->clusters is deprecated";
    sort keys %{ App::clad->new('--server')->cluster_list };
  };
}

sub aliases
{
  (undef) = @_;
  Carp::carp "Class method call of Clustericious::Admin->aliases is deprecated";
  sort keys %{ App::clad->new('--server')->alias };
}

sub run
{
  my $self = shift;
  
  ref $self
  ? $self->SUPER::new(@_)
  : do {
    Carp::carp "Class method call of Clustericious::Admin->run is deprecated";
    my($opts, $cluster, @cmd) = @_;
    App::clad->new(
      ($opts->{n} ? ('-n') : ()),
      ($opts->{l} ? ('-l' => $opts->{l}) : ()),
      ($opts->{a} ? ('-a') : ()),
      $cluster, @cmd,
    )->run;
  };
}

1;
