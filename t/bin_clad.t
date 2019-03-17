use strict;
use warnings;
use Test::More tests => 1;
use Test::Script;
use Env qw( @PERL5LIB );
use Path::Class qw( dir );

unshift @PERL5LIB, dir('t/lib')->absolute->stringify;

script_compiles 'bin/clad';
