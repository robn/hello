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

has loop     => ( is => 'ro', isa => class_type('IO::Async::Loop'), required => 1 );
has filename => ( is => 'ro', isa => Str,                           required => 1 );

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
  
sub world {
  my ($self) = @_;

  my $config = $self->_config_raw;

  my $default_config = delete $config->{tester}->{_defaults_} // {};
  my $default_interval = delete $default_config->{interval};
  my $default_timeout  = delete $default_config->{timeout};

  my @collectors;

  for my $collector_type (keys $config->{collector}->%*) {
    my $collector_config = delete $config->{collector}->{$collector_type} // {};

    my $collector_package = "Hello::Collector::$collector_type";
    require_module($collector_package); # XXX fail

    my $collector = $collector_package->new(
      loop => $self->loop,
      %$collector_config,
    );

    $Logger->log("created '$collector_type' collector");

    $collector->init;

    push @collectors, $collector;
  }

  my @testers;

  for my $tester_type (keys $config->{tester}->%*) {
    my $tester_list = delete $config->{tester}->{$tester_type} // [];

    my $tester_package = "Hello::Tester::$tester_type";
    require_module($tester_package); # XXX fail

    for my $tester_config ($tester_list->@*) {
      my $tester_interval = delete $tester_config->{interval} // $default_interval;
      my $tester_timeout  = delete $tester_config->{timeout}  // $default_timeout;

      my $tester = $tester_package->new(
        loop     => $self->loop,
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

      push @testers, $tester;
    }
  }

  Hello::World->new(
    loop => $self->loop,
    collectors => \@collectors,
    testers => \@testers,
  );
}

1;