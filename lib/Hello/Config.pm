package Hello::Config;

use 5.020;
use Moo;
use experimental qw(postderef);

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
      world  => $self->world,
      class  => $config->{class},
      id     => $id,
      config  => {
        map { $_ => $config->{$_} }
          grep { ! m/^(?:world|class|id|config)$/ }
            keys %$config,
      },
    );
    $collector->inflate;
  }

  for my $id (keys $config->{group}->%*) {
    my $config = $config->{group}->{$id} // {};

    my $group = Hello::Config::Group->new(
      world  => $self->world,
      class  => $config->{class},
      id     => $id,
      defined_kv(default_interval => $default_interval),
      defined_kv(default_timeout  => $default_timeout),
      config => {
        map { $_ => $config->{$_} }
          grep { ! m/^(?:world|class|id|config)$/ }
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
      world  => $self->world,
      class  => $config->{class},
      id     => $id,
      config => {
        defined_kv(interval => $interval),
        defined_kv(timeout  => $timeout),
        map { $_ => $config->{$_} }
          grep { ! m/^(?:world|class|id|config)$/ }
            keys %$config,
      },
    );
    $tester->inflate;
  }
}

1;
