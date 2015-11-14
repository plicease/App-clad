use strict;
use warnings;
use 5.010;
use Test::Clustericious::Config;
use Test::More tests => 7;
use Capture::Tiny qw( capture );
use File::Temp qw( tempdir );
use Path::Class qw( file );
use YAML::XS qw( Dump Load );

do {
  no warnings;
  sub Sys::Hostname::hostname {
    'myfakehostname';
  }
};

require_ok 'App::clad';

create_config_ok 'Clad', {
  env => {
    FOO => "BAR",
  },
  clusters => {
    cluster1 => [ qw( host1 host2 host3 ) ],
    cluster2 => [ qw( host4 host5 host6 ) ],
  },
  alias => {
    alias1 => 'foo bar baz',
    alias2 => [qw( foo bar baz )],
  },
};

sub generate_stdin ($)
{
  my($data) = @_;
  my $fn = file( tempdir( CLEANUP => 1 ), "stdin.yml");
  $fn->spew(Dump($data));
  open STDIN, '<', $fn;
}

subtest 'exits' => sub {

  subtest 'exit 0' => sub {
    plan tests => 1;
    generate_stdin {
      env     => {},
      command => [ $^X, -E => "exit 0" ],
    };
    my($out, $err, $exit) = capture { App::clad->new('--server')->run };
    is $exit, 0, 'returns 0';
  };

  subtest 'exit 22' => sub {
    plan tests => 1;
    generate_stdin {
      env     => {},
      command => [ $^X, -E => "exit 22" ],
    };
    my($out, $err, $exit) = capture { App::clad->new('--server')->run };
    is $exit, 22, 'returns 22';
  };
  
  subtest 'kill 9' => sub {
    plan tests => 2;
    generate_stdin {
      env     => {},
      command => [ $^X, -E => "kill 9, \$\$" ],
    };
    my($out, $err, $exit) = capture { App::clad->new('--server')->run };
    is $exit, 2, 'returns 2';
    note $err;
    like $err, qr{died with signal \d+ on myfakehostname};
  };

};

subtest 'io' => sub {
  plan tests => 3;

  generate_stdin {
    env => {},
    command => [ $^X, -E => "say 'something to out'; say STDERR 'something to err'" ],
  };

  my($out, $err, $exit) = capture { App::clad->new('--server')->run };
  is $exit, 0, 'returns 0';
  like $out, qr{something to out}, 'out';
  like $err, qr{something to err}, 'err';
};

subtest 'env' => sub {
  plan tests => 2;

  generate_stdin {
    env => { FOO => 'bar' },
    command => [ $^X, -E => 'say "env:FOO=$ENV{FOO}:"' ],
  };

  my($out, $err, $exit) = capture { App::clad->new('--server')->run };
  is $exit, 0, 'returns 0';
  like $out, qr{env:FOO=bar:}, 'environment passed';
};

subtest 'verbose' => sub {
  plan tests => 6;

  generate_stdin {
    verbose => 1,
    env     => { FOO => 1, BAR => 2 },
    command => [ $^X, -E => '' ],
  };

  my($out, $err, $exit) = capture { App::clad->new('--server')->run };
  is $exit, 0, 'returns 0';
  my $data = Load($err);
  
  is $data->{command}->[1], '-E', 'command.1 = -E';
  is $data->{command}->[2], '', 'command.2 = ""';
  is $data->{env}->{FOO}, 1, 'env.FOO = 1';
  is $data->{env}->{BAR}, 2, 'env.BAR = 1';
  is $data->{verbose}, 1, 'verbose = 1';
  
  note $err;
};

subtest 'bad exe' => sub {

  generate_stdin {
    env => {},
    command => [ 'boguscommand', 'bogus arguments' ],
  };
  
  my($out, $err, $exit) = capture { App::clad->new('--server')->run };
  is $exit, 2, 'returns 2';
  like $err, qr{failed to execute on myfakehostname}, 'diagnostic';
};
