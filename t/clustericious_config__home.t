use Test2::V0 -no_srand => 1;
use lib 't/lib';
use Test::Clustericious::Config;
use Clustericious::Config;
use File::Temp qw( tempdir );

my $mock = do {
  
  my $dir  = tempdir( CLEANUP => 1 );
  my $dir2 = tempdir( CLEANUP => 1 );

  mock 'File::Glob' => (
    override => [
      bsd_glob => sub {
        my($path) = @_;
        return $dir  if $path eq '~';
        return $dir2 if $path eq '~foo';
        die "path = $path";
      },
    ],
  );
};

create_config_ok 'Foo', <<EOF;
---
test: <%= home %>
bar: <%= home 'foo' %>
EOF

my $config = Clustericious::Config->new('Foo');

my $dir = eval { $config->test };
ok $dir && -d $dir, "home is $dir and is a dir";

my $dir2 = eval { $config->bar };
ok $dir2 && -d $dir2, "home 'foo' is $dir2 and is a dir";

done_testing;
