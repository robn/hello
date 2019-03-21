package Hello::Config;

use 5.020;
use warnings;
use strict;
use experimental qw(postderef);

use Moo;
use Types::Standard qw(Str HashRef);
use Type::Utils qw(class_type);

use Carp qw(croak);
use TOML qw(from_toml);
use Module::Runtime qw(require_module);
use Defined::KV;

use Hello::Config::Collector;
use Hello::Config::Group;
use Hello::Config::Tester;

use Hello::World;
use Hello::Logger '$Logger';

has world    => ( is => 'ro', isa => class_type('Hello::World'), required => 1 );
has filename => ( is => 'ro', isa => Str,                        required => 1 );

has _config_raw => (
  is  => 'lazy',
  isa => HashRef,
  default => sub {
    my ($self) = @_;
    my ($config, $err) = from_toml(do { local (@ARGV, $/) = ($self->filename); <> }); # XXX not found
    croak "couldn't parse TOML config file '".$self->filename."': $err" unless $config;
    return $config;
  },
);

sub inflate {
  my ($self) = @_;

  my $config = $self->_config_raw;

  my $default_config = delete $config->{tester}->{_defaults_} // {};
  my $default_interval = delete $default_config->{interval};
  my $default_timeout  = delete $default_config->{timeout};

  for my $id (keys $config->{collector}->%*) {
    my $config = $config->{collector}->{$id} // {};

    my $collector = Hello::Config::Collector->new(
      world => $self->world,
      class => $config->{class},
      id    => $id,
      args  => {
        map { $_ => $config->{$_} }
          grep { ! m/^(?:world|class|args)$/ }
            keys %$config,
      },
    );
    $collector->inflate;
  }

  for my $id (keys $config->{group}->%*) {
    my $config = $config->{group}->{$id} // {};

    my $group = Hello::Config::Group->new(
      world => $self->world,
      class => $config->{class},
      id    => $id,
      defined_kv(default_interval => $default_interval),
      defined_kv(default_timeout  => $default_timeout),
      args  => {
        map { $_ => $config->{$_} }
          grep { ! m/^(?:world|class|args)$/ }
            keys %$config,
      },
    );
    $group->inflate;
  }

  for my $id (keys $config->{tester}->%*) {
    my $config = $config->{tester}->{$id} // {};

    my $interval = $config->{interval} // $default_interval;
    my $timeout  = $config->{timeout}  // $default_timeout;

    my $tester = Hello::Config::Tester->new(
      world => $self->world,
      class => $config->{class},
      id    => $id,
      args  => {
        defined_kv(interval => $interval),
        defined_kv(timeout  => $timeout),
        map { $_ => $config->{$_} }
          grep { ! m/^(?:world|class|args)$/ }
            keys %$config,
      },
    );
    $tester->inflate;
  }
}

=pod
      if (my $group_name = $config->{group}) {
        my $group = $config->{group}->{$group_name};
        unless ($group) {
          croak "E: $config->{name} references group '$group_name', but it doesn't exist";
        }
        for my $member_config ($group->{members}->@*) {
          my %member_tester_config = %$tester_config;
          delete $member_tester_config{group};

          $member_tester_config{name} .= ":$member_config->{name}";

          for my $k (keys %$member_config) {
            next if grep { $_ eq $k } qw(interval timeout name);
            $member_tester_config{$k} = $member_config->{$k} if exists $member_config->{$k};
          }

          my $tester = Hello::Config::Tester->new(
            world => $self->world,
            class => $tester_config->{class},
            args  => {
              defined_kv(interval => $tester_interval),
              defined_kv(timeout  => $tester_timeout),
              map { $_ => $tester_config->{$_} }
                grep { !m/^(?:world|class|args)$/ }
                  keys %member_tester_config,
            },
          );

          $self->world->add_tester($tester->inflate);
        }
      }

      else {
        my $tester = Hello::Config::Tester->new(
          world => $self->world,
          class => $tester_config->{class},
          args  => {
            defined_kv(interval => $tester_interval),
            defined_kv(timeout  => $tester_timeout),
            map { $_ => $tester_config->{$_} }
              grep { !m/^(?:world|class|args)$/ }
                keys %$tester_config,
          },
        );

        $Logger->log(join('; ',
          "created '$tester_type' tester",
          "name: ".$tester->name,
          "interval: ".$tester->interval,
          "timeout: ".$tester->timeout,
        ));

        $self->world->add_tester($tester->inflate);
      }
    }
  }
}
=cut

1;
