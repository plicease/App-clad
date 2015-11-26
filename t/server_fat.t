use strict;
use warnings;
use 5.010;
use Test::More tests => 4;
use Capture::Tiny qw( capture );
use Path::Class qw( file );
use File::Temp qw( tempdir );
use Clustericious::Admin::Dump qw( perl_dump );

my $remote_perl = $ENV{CLAD_TEST_REMOTE_PERL} // $^X;
my $server;

subtest 'get server code' => sub {

  plan tests => 1;

  require_ok 'Clustericious::Admin::Server';
  
  $server = file($INC{'Clustericious/Admin/Server.pm'})->slurp;
  $server =~ s{\s+$}{};
  $server .= "\n";

  note "remote perl: $remote_perl";
  note `$remote_perl -v`;
};

sub run_server
{
  my($test_pl) = @_;
  capture {
    delete local $ENV{PERL5LIB};
    delete local $ENV{PERLLIB};
    system $remote_perl, "$test_pl";
    $?;
  };
}

subtest 'basics' => sub {

  plan tests => 3;

  my $payload .= $server . perl_dump {
    env => {},
    version => 'dev',
    command => [ $remote_perl, -e => 'print "something to out\\n"; print STDERR "something to err\\n"' ],
  };

  my $test_pl = file( tempdir( CLEANUP => 1 ), 'test.pl');
  $test_pl->spew($payload);
  
  my($out, $err, $exit) = run_server $test_pl;

  is $exit, 0, 'returns 0';
  like $out, qr{something to out}, 'out';
  like $err, qr{something to err}, 'err';
};

subtest 'file' => sub {

  my $payload .= $server . perl_dump {
    env => {},
    version => 'dev',
    command => [ $remote_perl, -e => q{
      open IN, "<$ENV{FILE1}";
      local $/;
      $data = <IN>;
      close IN;
      die "file content did not match" unless $data eq 'rogerramjet';
    } ],
    files => [
      { name => "foo.txt", content => 'rogerramjet' },
    ],
  };

  my $test_pl = file( tempdir( CLEANUP => 1 ), 'test.pl');
  $test_pl->spew($payload);
  
  my($out, $err, $exit) = run_server $test_pl;

  is $exit, 0, 'returns 0';
  note "[out]\n$out" if $out;
  note "[err]\n$err" if $err;

};

subtest 'exit' => sub {

  my $payload .= $server . perl_dump {
    env => {},
    version => 'dev',
    command => [ $remote_perl, -e => 'exit 22' ],
  };

  my $test_pl = file( tempdir( CLEANUP => 1 ), 'test.pl');
  $test_pl->spew($payload);
  
  my($out, $err, $exit) = run_server $test_pl;

  is $exit >> 8, 22, 'returns 22';

};
