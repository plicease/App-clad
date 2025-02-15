use Test2::V0 -no_srand => 1;
use lib 't/lib';
use YAML::XS ();
use Clustericious::Config;

my %methods = map { $_ => 1 } grep { Clustericious::Config->can($_) } keys %Clustericious::Config::;

## we seem to get this once $VERSION is added to the .pm
delete $methods{$_} for qw( VERSION import );

## I'd like to move/remove these.
is [sort keys %methods], [sort qw( new AUTOLOAD DESTROY )], 'the big three';

done_testing;
