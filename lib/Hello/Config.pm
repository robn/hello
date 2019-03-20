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

sub apply {
  my ($self) = @_;

  my $config = $self->_config_raw;

  my $default_config = delete $config->{tester}->{_defaults_} // {};
  my $default_interval = delete $default_config->{interval};
  my $default_timeout  = delete $default_config->{timeout};

  for my $collector_type (keys $config->{collector}->%*) {
    my $collector_config = delete $config->{collector}->{$collector_type} // {};

    my $collector_package = "Hello::Collector::$collector_type";
    require_module($collector_package); # XXX fail

    my $collector = $collector_package->new(
      loop => $self->world->loop,
      %$collector_config,
    );

    $Logger->log("created '$collector_type' collector");

    $self->world->add_collector($collector);
  }

  for my $tester_type (keys $config->{tester}->%*) {
    my $tester_list = delete $config->{tester}->{$tester_type} // [];

    my $tester_package = "Hello::Tester::$tester_type";
    require_module($tester_package); # XXX fail

    for my $tester_config ($tester_list->@*) {
      my $tester_interval = delete $tester_config->{interval} // $default_interval;
      my $tester_timeout  = delete $tester_config->{timeout}  // $default_timeout;

      if (my $group_name = $tester_config->{group}) {
        my $group = $config->{group}->{$group_name};
        unless ($group) {
          croak "E: $tester_config->{name} references group '$group_name', but it doesn't exist";
        }
        for my $member_config ($group->{members}->@*) {
          my %member_tester_config = %$tester_config;
          delete $member_tester_config{group};

          $member_tester_config{name} .= ":$member_config->{name}";

          for my $k (keys %$member_config) {
            next if grep { $_ eq $k } qw(interval timeout name);
            $member_tester_config{$k} = $member_config->{$k} if exists $member_config->{$k};
          }

          my $tester = $tester_package->new(
            loop     => $self->world->loop,
            defined_kv(interval => $tester_interval),
            defined_kv(timeout  => $tester_timeout),
            %member_tester_config,
          );

          $Logger->log(join('; ',
            "created '$tester_type' tester",
            "name: ".$tester->name,
            "interval: ".$tester->interval,
            "timeout: ".$tester->timeout,
          ));

          $self->world->add_tester($tester);
        }
      }

      else {
        my $tester = $tester_package->new(
          loop     => $self->world->loop,
          defined_kv(interval => $tester_interval),
          defined_kv(timeout  => $tester_timeout),
          %$tester_config,
        );

        $Logger->log(join('; ',
          "created '$tester_type' tester",
          "name: ".$tester->name,
          "interval: ".$tester->interval,
          "timeout: ".$tester->timeout,
        ));

        $self->world->add_tester($tester);
      }
    }
  }
}

1;
