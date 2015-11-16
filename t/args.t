use strict;
use warnings;
use Test::Clustericious::Config;
use Test::More;
BEGIN { plan skip_all => 'test requires Test::Exit' unless eval qq{ use Test::Exit; 1 } }
use App::clad;
use Capture::Tiny qw( capture );

plan tests => 14;

create_config_ok 'Clad', {
  env => {
    FOO => "BAR",
  },
  cluster => {
    cluster1 => [ qw( host1 host2 host3 ) ],
    cluster2 => [ qw( host4 host5 host6 ) ],
  },
  alias => {
    alias1 => 'foo bar baz',
    alias2 => [qw( foo bar baz )],
  },
};

subtest 'dry run' => sub {
  plan tests => 2;

  is(App::clad->new('-n', 'cluster1', 'echo')->dry_run, 1, '-n on');
  is(App::clad->new('cluster1', 'echo')->dry_run,       0, '-n off');

};

subtest 'color' => sub {
  plan tests => 2;

  local $App::clad::_stdout_is_terminal = sub { 1 };

  is(App::clad->new('-a', 'cluster1', 'echo')->color, 0, '-a on');
  is(App::clad->new('cluster1', 'echo')->color,       1, '-a off');

};

subtest 'user' => sub {
  plan tests => 2;
  
  is(App::clad->new('-l' => 'foo', 'cluster1', 'echo')->user, 'foo', '-l foo');
  is(App::clad->new('cluster1', 'echo')->user,                undef, 'no user');
  
};

subtest 'help' => sub {
  is exit_code { App::clad->new('--help') }, 1, "--help";
  is exit_code { App::clad->new('-h')     }, 1, "-h";
};

subtest 'version' => sub {
  plan tests => 1;

  foreach my $arg (qw( --version ))
  {
    subtest $arg => sub {
      plan tests => 2;
      my($out, $err, $exit) = capture { exit_code { App::clad->new($arg) } };
      is $exit, 1, 'exit = 1';
      note "[out]\n$out\n" if $out;
      note "[err]\n$err\n" if $err;
      is $err, "App::clad version @{[ $App::clad::VERSION // 'dev' ]}\n", 'output';
    };
  }
};

subtest 'not enough arguments' => sub {
  plan tests => 2;

  is exit_code { App::clad->new }, 1, 'no args';
  is exit_code { App::clad->new('cluster1') }, 1, 'one args';

};

subtest 'invalid cluster' => sub {
  plan tests => 2;
  my($out, $err, $exit) = capture { exit_code { App::clad->new("foo", "bar") } };
  is $exit, 2, 'exit = 2';
  note "[err]\n$err";
  like $err, qr{unknown cluster: foo}, "diagnostic";
};

subtest 'invalid cluster with user' => sub {
  plan tests => 2;
  my($out, $err, $exit) = capture { exit_code { App::clad->new('bar@foo', "bar") } };
  is $exit, 2, 'exit = 2';
  note "[err]\n$err";
  like $err, qr{unknown cluster: foo}, "diagnostic";
};

subtest 'server' => sub {

  is(App::clad->new('--server')->server, 1, 'clad.server = 1');
  is(App::clad->new('cluster1','uptime')->server, 0, 'clad.server = 0');
};

subtest 'verbose' => sub {
  plan tests => 2;

  is(App::clad->new('--verbose', 'cluster1', 'echo')->verbose, 1, '--verbose on');
  is(App::clad->new('cluster1', 'echo')->verbose,       0, '--verbose off');

};

subtest 'serial' => sub {
  plan tests => 2;

  is(App::clad->new('--serial', 'cluster1', 'echo')->serial, 1, '--serial on');
  is(App::clad->new('cluster1', 'echo')->serial,       0, '--serial off');

};

subtest 'illegal options as cluster' => sub {
  plan tests => 2;
  my($out, $err, $exit) = capture { exit_code { App::clad->new("--foo", "bar") } };
  is $exit, 1, 'exit = 1';
  like $out, qr{Unknown option: foo}, "diagnostic";
};

subtest 'illegal options as command' => sub {
  plan tests => 2;
  my($out, $err, $exit) = capture { exit_code { App::clad->new("cluster1", "--bar") } };
  is $exit, 1, 'exit = 1';
  like $out, qr{Unknown option: bar}, "diagnostic";
};
