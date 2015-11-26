use strict;
use warnings;
use 5.010;
use Test::More tests => 1;
use Capture::Tiny qw( capture );
use Path::Class qw( file );
use File::Temp qw( tempdir );
use Clustericious::Admin::Dump qw( perl_dump );

subtest 'basics' => sub {

  require_ok 'Clustericious::Admin::Server';
  
  my $payload = file($INC{'Clustericious/Admin/Server.pm'})->slurp;
  $payload =~ s{\s+$}{};
  
  $payload .= "\n" . perl_dump {
    env => {},
    version => 'dev',
    command => [ $^X, -E => "say 'something to out'; say STDERR 'something to err'" ],
  };

  my $test_pl = file( tempdir( CLEANUP => 1 ), 'test.pl');
  $test_pl->spew($payload);
  
  my($out, $err, $exit) = capture { system $^X, "$test_pl" };
  is $exit, 0, 'returns 0';
  like $out, qr{something to out}, 'out';
  like $err, qr{something to err}, 'err';
};


