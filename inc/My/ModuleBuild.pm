package My::ModuleBuild;

use strict;
use warnings;
use base qw( Module::Build );

sub new
{
  my($class, %args) = @_;

  $args{get_options} = {
    clad_server_command      => { type => '=s', default => $ENV{CLAD_BUILD_SERVER_COMMAND}     // 'clad --server', },
    clad_fat                 => {               default => $ENV{CLAD_BUILD_FAT}                // 0,               },
    clad_fat_server_command  => { type => '=s', default => $ENV{CLAD_BUILD_FAT_SERVER_COMMAND} // 'perl',          },
  };
  
  my $self = $class->SUPER::new(%args);
  
  $self->config_data($_, $self->args($_)) for qw( clad_server_command clad_fat clad_fat_server_command );
  
  $self;
}

1;
