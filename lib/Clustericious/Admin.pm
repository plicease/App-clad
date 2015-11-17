package Clustericious::Admin;

use strict;
use warnings;
use App::clad;
use Carp ();

# ABSTRACT: Parallel SSH client
# VERSION

=head1 SYNOPSIS

 % perldoc clad

=head1 DESCRIPTION

This module used to contain the machinery to implement the L<clad> command.
This was moved into L<App::clad> when it was rewritten.  This module is
provided for compatibility.  In the future it may provide a Perl level API
for L<clad>.  It currently provides a deprecated interface which will be
removed from a future version, but not before B<January 13, 2015>.

=head1 FUNCTIONS

=head2 banners

B<DEPRECATED>

 my @banners = Clustericious::Admin->banners;

Returns the banners from the configuration file as a list.

=cut


sub banners
{
  (undef) = @_;
  Carp::carp "Class method call of Clustericious::Admin->banners is deprecated";
  ();
}

=head2 clusters

B<DEPRECATED>

 my @clusters = Clustericious::Admin->clusters;

Returns the list of clusters from the configuration file.

=cut

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

=head2 aliases

B<DEPRECATED>

 my @aliases = Clustericious::Admin->aliases;

Returns the alias names from the configuration file as a list.

=cut

sub aliases
{
  (undef) = @_;
  Carp::carp "Class method call of Clustericious::Admin->aliases is deprecated";
  sort keys %{ App::clad->new('--server')->alias };
}

=head2 run

B<DEPRECATED>

 Clustericious::Admin->new(\%options, $cluster, $command);

Run the given command on all the hosts in the given cluster.  Returns 0.  Options
is a hash reference which may include any of the following keys.

=over 4

=item n

 { n => 1 }

Dry run

=item l

 { l => $user }

Set the username that you want to connect with.

=item a

 { a => 1 }

Turn off color.

=back

=cut

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

=head1 CAVEATS

L<Clustericious::Admin> and L<clad> require an L<AnyEvent> event loop that allows
entering the event loop by calling C<recv> on a condition variable.  This is not
supported by all L<AnyEvent> event loops and is discouraged by its documentation
for CPAN modules.

=head1 SEE ALSO

=over 4

=item L<clad>

=back

=cut

