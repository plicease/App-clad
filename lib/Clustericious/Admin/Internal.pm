package Clustericious::Admin::Internal;

use strict;
use warnings;
use File::Spec;
use File::Glob qw( bsd_glob );
use 5.010001;

sub _testing
{
  state $test = 0;
  my($class, $new) = @_;
  $test = $new if defined $new;
  $test;
}

sub _config_path
{
  grep { -d $_ }
    map { File::Spec->catdir(@$_) } 
    grep { defined $_->[0] }
    (
      [ $ENV{CLUSTERICIOUS_CONF_DIR} ],
      (!_testing) ? (
        [ bsd_glob('~'), 'etc' ],
        [ bsd_glob('~/.config/Perl/Clustericious') ],
        [ '', 'etc' ],
      ) : (),
    );
}

1;
