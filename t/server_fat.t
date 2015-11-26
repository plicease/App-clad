use strict;
use warnings;
use 5.010;
use Test::More tests => 2;
use Capture::Tiny qw( capture );
use Path::Class qw( file );
use File::Temp qw( tempdir );
use Clustericious::Admin::Dump qw( perl_dump );

my $remote_perl = $ENV{CLAD_TEST_REMOTE_PERL} // $^X;

note "remote perl: $remote_perl";
note `$remote_perl -v`;

subtest 'basics' => sub {

  require_ok 'Clustericious::Admin::Server';
  
  my $payload = file($INC{'Clustericious/Admin/Server.pm'})->slurp;
  $payload =~ s{\s+$}{};
  
  $payload .= "\n" . perl_dump {
    env => {},
    version => 'dev',
    command => [ $remote_perl, -e => 'print "something to out\\n"; print STDERR "something to err\\n"' ],
  };

  my $test_pl = file( tempdir( CLEANUP => 1 ), 'test.pl');
  $test_pl->spew($payload);
  
  my($out, $err, $exit) = capture {
    delete local $ENV{PERL5LIB};
    delete local $ENV{PERLLIB};
    system $remote_perl, "$test_pl";
  };

  is $exit, 0, 'returns 0';
  like $out, qr{something to out}, 'out';
  like $err, qr{something to err}, 'err';
};
