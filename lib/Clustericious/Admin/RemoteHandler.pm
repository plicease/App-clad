package Clustericious::Admin::RemoteHandler;

use strict;
use warnings;
use 5.010;
use AE;
use AnyEvent::Open3::Simple 0.76;

# VERSION

sub new
{
  my($class, %args) = @_;
  
  # args: prefix, clad, user, host, payload
  
  my $self = bless {
    prefix  => $args{prefix},
    clad    => $args{clad},
    cv      => AE::cv,
    summary => $args{clad}->summary,
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
      $self->print_line(exit => $exit) if ($self->summary && !$signal) || $exit;
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

sub clad    { shift->{clad}    }
sub prefix  { shift->{prefix}  }
sub summary { shift->{summary} }

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
  
  my $last_line = $code =~ /^(exit|sig|fail)$/;
  
  return if $self->summary && ! $last_line;
  
  if($last_line)
  {
    print Term::ANSIColor::color('bold red') if $self->is_color;
  }
  else
  {
    print Term::ANSIColor::color($self->color) if $self->is_color;
  }

  printf "[%@{[ $self->clad->host_length ]}s %-4s] ", $self->prefix, $code;

  if(! $last_line)
  {
    if($code eq 'err')
    {
      print Term::ANSIColor::color('yellow') if $self->is_color;
    }
    else
    {
      print Term::ANSIColor::color('reset') if $self->is_color;
    }
  }
  
  print $line;
  
  if($last_line || $code eq 'err')
  {
    print Term::ANSIColor::color('reset') if $self->is_color;
  }
  
  print "\n";
}

sub cv { shift->{cv} }

1;
