package Hello::Group::Consul;

use 5.020;
use Moo;
use experimental qw(postderef);

use Types::Standard qw(Int Str ArrayRef HashRef);
use Type::Utils qw(class_type);

use Scalar::Util qw(blessed);
use Defined::KV;

use Hello::World;
use Hello::Logger '$Logger';

use Net::Async::Consul;

has world => ( is => 'ro', isa => class_type('Hello::World'), required => 1 );

has id => ( is => 'ro', isa => Str, required => 1 );

has service => ( is => 'ro', isa => Str, required => 1 );
has prefix =>  ( is => 'ro', isa => Str );

has default_interval => ( is => 'ro', isa => Int, default => sub { 120 } );
has default_timeout  => ( is => 'ro', isa => Int, default => sub { 30 } );

has tester => (
  is      => 'ro',
  isa     => HashRef[],   # XXX HashRef[class_type('Hello::Config::Tester'] ?
  default => sub { {} },
);

has logger => (
  is => 'lazy',
  default => sub {
    Hello::Logger->current_logger->proxy({ proxy_prefix => shift->id.': ' })
  },
);

has _catalog => (
  is => 'lazy',
  default => sub {
    my ($self) = @_;
    Net::Async::Consul->catalog(loop => $self->world->loop);
  },
);
has _catalog_index    => ( is => 'rw', isa => Int, default => 0);
has _catalog_services => ( is => 'rw', isa => ArrayRef );

has _kv => (
  is => 'lazy',
  default => sub {
    my ($self) = @_;
    Net::Async::Consul->kv(loop => $self->world->loop);
  },
);
has _kv_index        => ( is => 'rw', isa => Int, default => 0);
has _kv_service_args => ( is => 'rw', isa => HashRef );

has _registered_testers => ( is => 'rw', default => sub { {} } );

sub inflate {
  my ($self) = @_;

  $self->_catalog_start;
  $self->_kv_start;
}

sub _catalog_start {
  my ($self) = @_;

  $self->_catalog->service(
    $self->service,
    index => $self->_catalog_index,
    wait => '10s',
    cb => sub { $self->_catalog_change_handler(@_) },
    error_cb => sub { $self->_catalog_error_handler(@_) },
  );
}

sub _catalog_change_handler {
  my ($self, $services, $meta) = @_;

  # no change, timeout or other thing, just go back to sleep
  if ($meta->index == $self->_catalog_index) {
    $self->_catalog_start;
    return;
  }

  $self->logger->log(["consul: catalog change (index %d -> %d)", $self->_catalog_index, $meta->index]);
  $self->_catalog_index($meta->index);
  $self->_catalog_services($services);

  $self->_update_testers;

  $self->_catalog_start;
}

sub _catalog_error_handler {
  my ($self, $msg) = @_;

  $self->logger->log("consul: catalog error: $msg");
  $self->logger->log("consul: will retry in 10s");

  my $timer = IO::Async::Timer::Countdown->new(
    delay => 10,
    on_expire => sub {
      $self->_catalog_start;
    },
  );
  $timer->start;
  $self->world->loop->add($timer);
}

sub _kv_start {
  my ($self) = @_;

  if (defined $self->prefix) {
    $self->_kv->get_all(
      $self->prefix,
      index => $self->_kv_index,
      wait => '10s',
      cb => sub { $self->_kv_change_handler(@_) },
      error_cb => sub { $self->_kv_error_handler(@_) },
    );
  }
}

sub _kv_change_handler {
  my ($self, $data, $meta) = @_;

  # no change, timeout or other thing, just go back to sleep
  if ($meta->index == $self->_kv_index) {
    $self->_kv_start;
    return;
  }

  $self->logger->log(["consul: kv change (index %d -> %d)", $self->_kv_index, $meta->index]);
  $self->_kv_index($meta->index);

  my %service_args;
  my $prefix = $self->prefix;
  for my $kv ($data->@*) {
    my $k = $kv->key =~ s{^$prefix/}{}r;
    my ($node, $service, $arg, @rest) = split '/', $k;
    next unless $node && $service && $arg && !@rest;
    $service_args{$node}{$service}{$arg} = $kv->value;
  };
  $self->_kv_service_args(\%service_args);

  $self->_update_testers;

  $self->_kv_start;
}

sub _kv_error_handler {
  my ($self, $msg) = @_;

  $self->logger->log("consul: kv error: $msg");
  $self->logger->log("consul: will retry in 10s");

  my $timer = IO::Async::Timer::Countdown->new(
    delay => 10,
    on_expire => sub {
      $self->_kv_start;
    },
  );
  $timer->start;
  $self->world->loop->add($timer);
}

sub _update_testers {
  my ($self) = @_;

  my $services = $self->_catalog_services;
  my $service_args = $self->_kv_service_args;

  return unless $services && ($service_args || !defined $self->prefix);

  my %new_registered;

  for my $service ($services->@*) {

    for my $id (keys $self->tester->%*) {
      my $config = $self->tester->{$id} // {};

      my %member_config = %$config;
      $member_config{ip} = $service->service_address || $service->address
        if !$member_config{ip};
      $member_config{port} = $service->port
        if !$member_config{port} && $service->port;

      my $kv_config =
        $service_args->{$service->node}->{$service->id} //
        $service_args->{$service->node}->{$service->name} //
        {};
      $member_config{$_} = $kv_config->{$_} for keys %$kv_config;

      my $service_id = $service->id || $service->name;
      my $tester_id = join ':', $id, $self->id, $service->node, $service_id;

      my $tester = Hello::Config::Tester->new(
        world => $self->world,
        class => $config->{class},
        id    => $tester_id,
        args  => {
          defined_kv(interval => $self->default_interval),
          defined_kv(timeout  => $self->default_timeout),
          map { $_ => $member_config{$_} }
            grep { ! m/^(?:world|class|args)$/ }
              keys %member_config,
        },
      );

      $tester->inflate;

      $new_registered{$tester_id} = 1;
    }
  }

  for my $tester_id (sort keys $self->_registered_testers->%*) {
    next if exists $new_registered{$tester_id};
    $Logger->log("removing tester for lost service: $tester_id");
    $self->world->remove_tester($tester_id);
  }
  $self->_registered_testers(\%new_registered);
}

1;
