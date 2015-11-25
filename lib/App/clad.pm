package App::clad;

use strict;
use warnings;
use 5.010;
use Getopt::Long 1.24 qw( GetOptionsFromArray :config pass_through);
use Pod::Usage qw( pod2usage );
use Clustericious::Config 1.03;
use Term::ANSIColor ();
use Sys::Hostname qw( hostname );
use YAML::XS qw( Dump );
use JSON::MaybeXS qw( encode_json );
use File::Basename qw( basename );
use AE;

# ABSTRACT: Parallel SSH client
# VERSION

=head1 SYNOPSIS

 % perldoc clad

=head1 DESCRIPTION

This module provides the implementation for the L<clad> command.  See 
the L<clad> command for the public interface.

=head1 SEE ALSO

=over 4

=item L<clad>

=back

=cut

sub main
{
  my $clad = shift->new(@_);
  $clad->run;
}

# this hook is used for testing
# see t/args.t subtest 'color'
our $_stdout_is_terminal = sub { -t STDOUT };

sub new
{
  my $class = shift;

  my $self = bless {
    dry_run    => 0,
    color      => $_stdout_is_terminal->(),
    server     => 0,
    verbose    => 0,
    serial     => 0,
    next_color => -1,
    ret        => 0,
    fat        => 0,
    max        => 0,
    count      => 0,
    files      => [],
  }, $class;
  
  my @argv = @_;
  
  my $config_name = 'Clad';
  
  GetOptionsFromArray(
    \@argv,
    'n'        => \$self->{dry_run},
    'a'        => sub { $self->{color} = 0 },
    'l=s'      => \$self->{user},
    'server'   => \$self->{server},
    'verbose'  => \$self->{verbose},
    'serial'   => \$self->{serial},
    'config=s' => \$config_name,
    'fat'      => \$self->{fat},
    'max=s'    => \$self->{max},
    'file=s'   => $self->{files},
    'help|h'   => sub { pod2usage({ -verbose => 2}) },
    'version'  => sub {
      say STDERR 'App::clad version ', ($App::clad::VERSION // 'dev');
      exit 1;
    },
  ) || pod2usage(1);
  
  $self->{config} = Clustericious::Config->new($config_name);

  return $self if $self->server;
  
  # make sure there is at least one cluster specified
  # and that it doesn't look like a command line option
  pod2usage({ -exitval => 1, -message => "No clusters specified" })
    unless @argv;  
  pod2usage({ -exitvalue => 1, -message => "Unknown option: $1" })
    if $argv[0] =~ /^--?(.*)$/;

  $self->{clusters} = [ split ',', shift @argv ];

  # make sure there is at least one command argument is specified
  # and that it doesn't look like a command line option
  pod2usage({ -exitval => 1, -message => "No commands specified" })
    unless @argv;
  pod2usage({ -exitvalue => 1, -message => "Unknown option: $1" })
    if $argv[0] =~ /^--?(.*)$/;
  
  $self->{command}  = [ @argv ];

  if(my $expanded = $self->alias->{$self->command->[0]})
  {
    if(ref $expanded)
    {
      splice @{ $self->command }, 0, 1, @$expanded;
    }
    else
    {
      $self->command->[0] = $expanded;
    }
  }
  
  if($self->config->script(default => {})->{$self->command->[0]})
  {
    my $name = shift @{ $self->command };
    unshift @{ $self->command }, '$SCRIPT1';
    my $content = $self->config->script(default => {})->{$name};
    $self->{script} = [ $name => $content ];
  }
  
  my $ok = 1;
  
  foreach my $cluster (map { "$_" } $self->clusters)
  {
    $cluster =~ s/^.*@//;
    unless($self->cluster_list->{$cluster})
    {
      say STDERR "unknown cluster: $cluster";
      $ok = 0;
    }
  }
  
  foreach my $file ($self->files)
  {
    next if -r $file;
    say STDERR "unable to find $file";
    $ok = 0;
  }
  
  exit 2 unless $ok;
  
  $self;
}

sub config         { shift->{config}        }
sub dry_run        { shift->{dry_run}       }
sub color          { shift->{color}         }
sub clusters       { @{ shift->{clusters} } }
sub command        { shift->{command}       }
sub user           { shift->{user}          }
sub server         { shift->{server}        }
sub verbose        { shift->{verbose}       }
sub serial         { shift->{serial}        }
sub max            { shift->{max}           }
sub files          { @{ shift->{files} }    }
sub script         { @{ shift->{script} // [] } }
sub ssh_command    { shift->config->ssh_command(    default => 'ssh' ) }
sub ssh_options    { shift->config->ssh_options(    default => [ -o => 'StrictHostKeyChecking=no', 
                                                                 -o => 'BatchMode=yes',
                                                                 -o => 'PasswordAuthentication=no',
                                                                 '-T', ] ) }
sub ssh_extra      { shift->config->ssh_extra(      default => [] ) }
sub fat            { my $self = shift; $self->{fat} || $self->config->fat( default => 0 ) }

sub server_command
{
  my($self) = @_;
  
  $self->fat
  ? $self->config->fat_server_command( default => 'perl' )
  : $self->config->server_command(     default => 'clad --server' );
}

sub alias
{
  my($self) = @_;
  $self->config->alias( default => sub {
    my %deprecated = $self->config->aliases( default => {} );
    say STDERR "use of aliases key in configuration is deprecated, use alias instead"
        if %deprecated;
    \%deprecated;
  });
}

sub cluster_list
{
  my($self) = @_;
  $self->config->cluster( default => sub {
    my %deprecated = $self->config->clusters( default => {} );
    say STDERR "use of clusters key in configuration is deprecated, use cluster instead"
        if %deprecated;
    \%deprecated;
  });
}

sub ret
{
  my($self, $new) = @_;
  $self->{ret} = $new if defined $new;
  $self->{ret};
}

sub host_length
{
  my($self) = @_;

  unless($self->{host_length})
  {
    my $length = 0;
  
    foreach my $cluster (map { "$_" } $self->clusters)
    {
      my $user = $cluster =~ s/^(.*)@// ? $1 : $self->user;
      foreach my $host (@{ $self->cluster_list->{$cluster} })
      {
        my $prefix = ($user ? "$user\@" : '') . $host;
        $length = length $prefix if length $prefix > $length;
      }
    }
    
    $self->{host_length} = $length;
  }
  
  $self->{host_length};
}

sub next_color
{
  my($self) = @_;
  my @colors = $self->config->colors( default => ['green','cyan'] );
  $colors[ ++$self->{next_color} ] // $colors[ $self->{next_color} = 0 ];
}

sub payload
{
  my($self, $clustername) = @_;
  
  my %env = $self->config->env( default => {} );
  $env{CLUSTER}      //= $clustername; # deprecate
  $env{CLAD_CLUSTER} //= $clustername;

  my $payload = {
    env     => \%env,
    command => $self->command,
    verbose => $self->verbose,
    version => $App::clad::VERSION // 'dev',
  };
  
  if($self->files)
  {
    $payload->{require} = '1.01';
    
    foreach my $filename ($self->files)
    {
      my %h;
      open my $fh, '<', $filename;
      binmode $fh;
      $h{content} = do { local $/; <$fh> };
      close $fh;
      $h{name} = basename $filename;
      $h{mode} = (stat "/etc/passwd")[2] & 0777;
      push @{ $payload->{files} }, \%h;
    }
  }
  
  if($self->script)
  {
    my($name, $content) = $self->script;
    $payload->{require} = '1.01';
    
    push @{ $payload->{files} }, {
      name    => $name,
      content => $content,
      mode    => '0700',
      env     => 'SCRIPT1',
    };
  }
  
  if($self->fat)
  {
    # Perl on the remote end may not have YAML
    # (actually it may not have JSON::PP either
    # but at least that is part of the core as
    # of 5.14).
    $payload = encode_json($payload);
    require Clustericious::Admin::Server;
    open my $fh, '<', $INC{'Clustericious/Admin/Server.pm'};
    my $code = do { local $/; <$fh> };
    close $fh;
    $code =~ s{\s*$}{"\n"}e;
    $payload = $code . $payload;
  }
  else
  {
    $payload = Dump($payload);
  }
  
  $payload;
}

sub run
{
  my($self) = @_;
  
  return $self->run_server if $self->server;
  
  my $ret = 0;
  my @done;
  my $max = $self->max;

  
  foreach my $cluster (map { "$_" } $self->clusters)
  {
    my $user = $cluster =~ s/^(.*)@// ? $1 : $self->user;

    my $payload = $self->payload($cluster);

    foreach my $host (@{ $self->cluster_list->{$cluster} })
    {
      my $prefix = ($user ? "$user\@" : '') . $host;
      if($self->dry_run)
      {
        say "$prefix % @{ $self->command }";
      }
      else
      {
        my $remote = Clustericious::Admin::RemoteHandler->new(
          prefix  => $prefix,
          clad    => $self,
          user    => $user,
          host    => $host,
          payload => $payload,
        );

        my $done = $remote->cv;
        
        $done->cb(sub {
          my $count = --$self->{count};
          $self->{cv}->send if $self->{cv};
        }) if $max;
        
        if($max)
        {
          my $count = ++$self->{count};
          if($count >= $max)
          {
            $self->{cv} = AE::cv;
            $self->{cv}->recv;
            delete $self->{cv};
          }
        }
        
        $self->serial ? $done->recv : push @done, $done;
      }
    }
  }
  
  $_->recv for @done;
  
  $self->ret;
}

sub run_server
{
  require Clustericious::Admin::Server;
  Clustericious::Admin::Server->_server(*STDIN);
}

package Clustericious::Admin::RemoteHandler;

use strict;
use warnings;
use AE;
use AnyEvent::Open3::Simple 0.76;

# VERSION

sub new
{
  my($class, %args) = @_;
  
  # args: prefix, clad, user, host, payload
  
  my $self = bless {
    prefix => $args{prefix},
    clad   => $args{clad},
    cv     => AE::cv,
  }, $class;
  
  my $clad = $args{clad};
  
  my $done = $self->{cv};
  
  my $ipc = AnyEvent::Open3::Simple->new(
    on_start => sub {
      my($proc, $program, @args) = @_;
      $self->print_line(star => "% $program @args") if $clad->verbose;
    },
    on_stdout => sub {
      my($proc, $line) = @_;
      $self->print_line(out => $line);
    },
    on_stderr => sub {
      my($proc, $line) = @_;
      $self->print_line(err => $line);
    },
    on_exit => sub {
      my($proc, $exit, $signal) = @_;
      $self->print_line(exit => $exit) if $exit;
      $self->print_line(sig  => $signal) if $signal;
      $clad->ret(2) if $exit || $signal;
      $done->send;
    },
    on_error => sub {
      my($error) = @_;
      $self->print_line(fail => $error);
      $clad->ret(2);
      $done->send;
    },
  );
  
  $ipc->run(
    $clad->ssh_command,
    $clad->ssh_options,
    $clad->ssh_extra,
    ($args{user} ? ('-l' => $args{user}) : ()),
    $args{host},
    $clad->server_command,
    \$args{payload},
  );
  
  $self;
}

sub clad   { shift->{clad} }
sub prefix { shift->{prefix} }

sub color
{
  my($self) = @_;
  $self->{color} //= $self->clad->next_color;
}

sub is_color
{
  my($self) = @_;
  $self->{is_color} //= $self->clad->color;
}

sub print_line
{
  my($self, $code, $line) = @_;
  
  print Term::ANSIColor::color($self->color) if $self->is_color;
  printf "[%@{[ $self->clad->host_length ]}s %-4s] ", $self->prefix, $code;
  print Term::ANSIColor::color('reset') if $self->is_color;
  print $line, "\n";
}

sub cv { shift->{cv} }

1;
