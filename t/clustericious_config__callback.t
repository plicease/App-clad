use Test2::V0 -no_srand => 1;
use lib 't/lib';
use Test::Clustericious::Config;
use Clustericious::Config;
use YAML::XS qw( Load );

subtest 'base object' => sub {

  my $cb = Clustericious::Config::Callback->new('foo','bar','baz');
  isa_ok $cb, 'Clustericious::Config::Callback';

  is [$cb->args], [qw(foo bar baz )], 'cb.args';

  is $cb->execute, '', 'cb.execute';

  ok $cb->to_yaml, "cb.to_yaml = @{[ $cb->to_yaml ]}";
  
  my $yaml = "---\na: @{[ $cb->to_yaml ]}\n";
  
  my $cb2 = Load($yaml)->{a};
  
  is [$cb2->args], [qw( foo bar baz )], 'cb2.args (restored!)';
};

subtest 'derrived object' => sub {
  plan tests => 2;

  do {
    package Foo;
    use base qw( Clustericious::Config::Callback );
    sub execute { join ':', shift->args }
  };
  
  my $cb = Foo->new('abc','def');
  isa_ok $cb, 'Clustericious::Config::Callback';
  is $cb->execute, 'abc:def', 'cb.execute';

};

done_testing;
