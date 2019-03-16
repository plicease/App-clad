use strict;
use warnings;
use Test::More tests => 1;
use Test::Script;
use Env qw( @PERL5LIB );
use Path::Tiny qw( path );

unshift @PERL5LIB, path('t/lib')->absolute->stringify;

script_compiles 'bin/clad';
