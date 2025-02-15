use Test2::V0 -no_srand => 1;
use Config;

eval q{ require Test::More };

# This .t file is generated.
# make changes instead to dist.ini

my %modules;
my $post_diag;

BEGIN { eval q{ use EV; } }
$modules{$_} = $_ for qw(
  AE
  AnyEvent::Open3::Simple
  Capture::Tiny
  Cpanel::JSON::XS
  EV
  File::chdir
  Getopt::Long
  Hash::Merge
  Log::Log4perl
  Module::Build
  Mojo::Loader
  Mojo::Template
  Mojo::URL
  Path::Class
  Path::Class::Dir
  Path::Class::File
  Sys::HostAddr
  Test2::API
  Test2::Mock
  Test2::Plugin::FauxHomeDir
  Test2::V0
  Test::Exit
  Test::More
  Test::Script
  YAML::XS
);

$post_diag = sub {
  use lib 't/lib';
  if(eval { require App::clad })
  {
    diag "server_command:     ", App::clad::_local_default('clad_server_command',     'no default');
    diag "fat                 ", App::clad::_local_default('clad_fat',                'no default');
    diag "fat_server_command: ", App::clad::_local_default('clad_fat_server_command', 'no default');
  }
  else
  {
    diag "error loading App::clad: $@";
  }
};

my @modules = sort keys %modules;

sub spacer ()
{
  diag '';
  diag '';
  diag '';
}

pass 'okay';

my $max = 1;
$max = $_ > $max ? $_ : $max for map { length $_ } @modules;
our $format = "%-${max}s %s"; 

spacer;

my @keys = sort grep /(MOJO|PERL|\A(LC|HARNESS)_|\A(SHELL|LANG)\Z)/i, keys %ENV;

if(@keys > 0)
{
  diag "$_=$ENV{$_}" for @keys;
  
  if($ENV{PERL5LIB})
  {
    spacer;
    diag "PERL5LIB path";
    diag $_ for split $Config{path_sep}, $ENV{PERL5LIB};
    
  }
  elsif($ENV{PERLLIB})
  {
    spacer;
    diag "PERLLIB path";
    diag $_ for split $Config{path_sep}, $ENV{PERLLIB};
  }
  
  spacer;
}

diag sprintf $format, 'perl ', $];

foreach my $module (sort @modules)
{
  if(eval qq{ require $module; 1 })
  {
    my $ver = eval qq{ \$$module\::VERSION };
    $ver = 'undef' unless defined $ver;
    diag sprintf $format, $module, $ver;
  }
  else
  {
    diag sprintf $format, $module, '-';
  }
}

if($post_diag)
{
  spacer;
  $post_diag->();
}

spacer;

done_testing;
