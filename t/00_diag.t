use strict;
use warnings;
use Config;
use Test::More tests => 1;

# This .t file is generated.
# make changes instead to dist.ini

my %modules;
my $post_diag;

BEGIN { eval q{ use EV; } }
$modules{$_} = $_ for qw(
  AE
  AnyEvent::Open3::Simple
  Capture::Tiny
  Clustericious::Config
  Cpanel::JSON::XS
  EV
  File::ShareDir::Dist
  File::chdir
  Getopt::Long
  Hash::Merge
  JSON::MaybeXS
  JSON::PP
  JSON::XS
  Log::Log4perl
  Module::Build
  Mojo::Loader
  Mojo::Template
  Mojo::URL
  Path::Class
  Path::Class::Dir
  Path::Class::File
  Sys::HostAddr
  Term::Prompt
  Test2::API
  Test2::Plugin::FauxHomeDir
  Test::Exit
  Test::More
  Test::Script
  Test::Warn
  YAML::XS
  autodie
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

foreach my $module (@modules)
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

