package Clustericious::Admin::Dump;

use strict;
use warnings;
use 5.010;
use Data::Dumper ();
use base qw( Exporter );

our @EXPORT_OK = qw( perl_dump );

# VERSION

sub perl_dump ($)
{
  "#perl\n" .
  Data::Dumper
    ->new([$_[0]])
    ->Terse(1)
    ->Indent(0)
    ->Dump;
}

1;
