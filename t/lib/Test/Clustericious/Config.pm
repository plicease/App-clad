package Test::Clustericious::Config;

use strict;
use warnings;
use 5.010001;
use Test2::Plugin::FauxHomeDir;
use File::Glob qw( bsd_glob );
use YAML::XS qw( DumpFile );
use File::Path qw( mkpath );
use Clustericious::Config;
use Mojo::Loader;
use Test2::API qw( context );
use Test2::Mock;
use base qw( Exporter );

our @EXPORT = qw( create_config_ok create_directory_ok home_directory_ok create_config_helper_ok );
our @EXPORT_OK = @EXPORT;
our %EXPORT_TAGS = ( all => \@EXPORT );

my $config_dir;
my $mock;

sub _init
{
  $config_dir = bsd_glob('~/etc');
  mkdir $config_dir;
  $mock = Test2::Mock->new( class => 'Clustericious::Config::Util' );
  $mock->override(
    path => sub {
      ($config_dir)
    },
  );
}

BEGIN { _init() }

sub create_config_ok ($;$$)
{
  my($config_name, $config, $test_name) = @_;

  my $fn = "$config_name.conf";
  $fn =~ s/::/-/g;
  
  unless(defined $config)
  {
    my $caller = caller;
    Mojo::Loader::load_class($caller) unless $caller eq 'main';
    $config = Mojo::Loader::data_section($caller, "etc/$fn");
  }
  
  my @diag;
  my $config_filename;
  
  my $ctx = context();
  my $ok = 1;
  if(!defined $config)
  {
    $config = "---\n";
    push @diag, "unable to locate text for $config_name";
    $ok = 0;
    $test_name //= "create config for $config_name";
  }
  else
  {
    $config_filename = "$config_dir/$fn";
  
    eval {
      if(ref $config)
      {
        DumpFile($config_filename, $config);
      }
      else
      {
        open my $fh, '>', $config_filename;
        print $fh $config;
        close $fh;
      }
    };
    if(my $error = $@)
    {
      $ok = 0;
      push @diag, "exception: $error";
    }
  
    $test_name //= "create config for $config_name at $config_filename";
  
    # remove any cached copy if necessary
    Clustericious::Config::Util->uncache($config_name);
  }

  $ctx->ok($ok, $test_name);
  $ctx->diag($_) for @diag;  
  
  $ctx->release;
  
  return $config_filename;
}

sub create_directory_ok ($;$)
{
  my($path, $test_name) = @_;

  my $fullpath;
  my $ok;
  
  if(defined $path)
  {
    $fullpath = $path;
    $fullpath =~ s{^/}{};
    $fullpath = bsd_glob("~/$fullpath");
    mkpath $fullpath, 0, 0700;
  
    $test_name //= "create directory $fullpath";
    $ok = -d $fullpath;
  }
  else
  {
    $test_name //= "create directory [undef]";
    $ok = 0;
  }
  
  my $ctx = context();
  $ctx->ok($ok, $test_name);
  $ctx->release;
  return $fullpath;
}

sub home_directory_ok (;$)
{
  my($test_name) = @_;
  
  my $fullpath = bsd_glob('~');
  
  $test_name //= "home directory $fullpath";
  
  my $ctx = context();
  $ctx->ok(-d $fullpath, $test_name);
  $ctx->release;
  return $fullpath;
}

sub create_config_helper_ok ($$;$)
{
  my($helper_name, $helper_code, $test_name) = @_;
  
  $test_name //= "create config helper $helper_name";
  my $ok = 1;
   
  require Clustericious::Config::Helpers;
  do {
    no strict 'refs';
    *{"Clustericious::Config::Helpers::$helper_name"} = $helper_code;
  };
  push @Clustericious::Config::Helpers::EXPORT, $helper_name;
  
  my $ctx = context();
  $ctx->ok($ok, $test_name);
  $ctx->release;
  return $ok;
}

1;
