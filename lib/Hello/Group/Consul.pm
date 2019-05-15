package Hello::Group::Consul;

use 5.020;
use Moo;
use experimental qw(postderef);

with 'Hello::Group';

use Types::Standard qw(Str Bool Int);
use Type::Utils qw(class_type);

use Hello::World;

use Net::Async::Consul;

has service => ( is => 'ro', isa => Str, required => 1 );
has prefix =>  ( is => 'ro', isa => Str );

has all_datacenters => (
  is      => 'ro',
  isa     => Bool,
  coerce  => sub { $_[0] && ("$_[0]" ne "false") },
);

has _consul_port => ( is => 'ro', isa => Int, default => 8500 );


sub start {
  my ($self) = @_;

  my $c = Net::Async::Consul->new(
    loop => $self->world->loop,
    port => $self->_consul_port,
  );

  if ($self->all_datacenters) {
    $c->catalog->datacenters(
      cb => sub {
        my ($dcs) = @_;
        Hello::Group::Consul::Worker->new(
          group => $self,
          datacenter => $_,
        )->inflate for @$dcs;
      },
      error_cb => sub { $self->_start_error_handler(@_) },
    );
  }

  else {
    $c->agent->self(
      cb => sub {
        my ($data) = @_;
        Hello::Group::Consul::Worker->new(
          group => $self,
          datacenter => $data->config->{Datacenter},
        )->inflate;
      },
      error_cb => sub { $self->_start_error_handler(@_) },
    );
  }
}

sub _start_error_handler {
  my ($self, $msg) = @_;

  $self->logger->log("consul: startup error (dc lookup): $msg");
  $self->logger->log("consul: will retry in 10s");

  my $timer = IO::Async::Timer::Countdown->new(
    delay => 10,
    on_expire => sub {
      $self->start;
    },
  );
  $timer->start;
  $self->world->loop->add($timer);
}


package
  Hello::Group::Consul::Worker;

use 5.020;
use Moo;
use experimental qw(postderef);

use Types::Standard qw(Int Str ArrayRef HashRef);
use Type::Utils qw(class_type);

use Defined::KV;

has group => ( is => 'ro', isa => class_type('Hello::Group::Consul'), required => 1 );

has datacenter => ( is => 'ro', isa => Str, required => 1 );

has logger => (
  is => 'lazy',
  default => sub {
    my ($self) = @_;
    Hello::Logger->current_logger->proxy({
      proxy_prefix => $self->group->id.': '.$self->datacenter.': ',
    });
  },
);

has _catalog => (
  is => 'lazy',
  default => sub {
    my ($self) = @_;
    Net::Async::Consul->catalog(
      loop => $self->group->world->loop,
      port => $self->group->_consul_port,
    );
  },
);
has _catalog_index    => ( is => 'rw', isa => Int, default => 0);
has _catalog_services => ( is => 'rw', isa => ArrayRef );

has _kv => (
  is => 'lazy',
  default => sub {
    my ($self) = @_;
    Net::Async::Consul->kv(
      loop => $self->group->world->loop,
      port => $self->group->_consul_port,
    );
  },
);
has _kv_index          => ( is => 'rw', isa => Int, default => 0);
has _kv_service_config => ( is => 'rw', isa => HashRef );

has _last_member_ids => ( is => 'rw', isa => ArrayRef, default => sub { [] } );

sub inflate {
  my ($self) = @_;

  $self->_catalog_start;
  $self->_kv_start;
}

sub _catalog_start {
  my ($self) = @_;

  #$self->logger->log(["starting catalog receiver for %s", $self->datacenter]);

  $self->_catalog->service(
    $self->group->service,
    dc => $self->datacenter,
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

  $self->logger->log(["catalog change (index %d -> %d)", $self->_catalog_index, $meta->index]);
  $self->_catalog_index($meta->index);
  $self->_catalog_services($services);

  $self->_update_membership;

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
  $self->group->world->loop->add($timer);
}

sub _kv_start {
  my ($self) = @_;

  #$self->logger->log(["starting kv receiver for %s", $self->datacenter]);

  if (defined $self->group->prefix) {
    $self->_kv->get_all(
      $self->group->prefix,
      dc => $self->datacenter,
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

  $self->logger->log(["kv change (index %d -> %d)", $self->_kv_index, $meta->index]);
  $self->_kv_index($meta->index);

  my %service_config;
  my $prefix = $self->group->prefix;
  for my $kv ($data->@*) {
    my $k = $kv->key =~ s{^$prefix/}{}r;
    my ($node, $service, $key, @rest) = split '/', $k;
    next unless $node && $service && $key && !@rest;
    $service_config{$node}{$service}{$key} = $kv->value;
  };
  $self->_kv_service_config(\%service_config);

  $self->_update_membership;

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
  $self->group->world->loop->add($timer);
}

sub _update_membership {
  my ($self) = @_;

  my $services = $self->_catalog_services;
  my $service_config = $self->_kv_service_config;

  return unless $services && ($service_config || !defined $self->group->prefix);

  my @member_ids;

  for my $service ($services->@*) {
    my $kv_config =
      $service_config->{$service->node}->{$service->id} //
      $service_config->{$service->node}->{$service->name} //
      {};

    my %config = (
      %$kv_config,
      ip => $service->service_address || $service->address,
      ($service->port ? (port => $service->port) : ()),
    );

    my $member_id = join ':', $self->datacenter, $service->node, $service->id;

    $self->group->add_member(
      Hello::Group::Member->new(
        id => $member_id,
        config => \%config,
      )
    );

    push @member_ids, $member_id;
  }

  # figure out any members that don't exist anymore, and remove them
  # do this by comparing to whatever we had last time
  my %member_ids = map { $_ => 1 } @member_ids;
  my @lost_member_ids = grep { !$member_ids{$_} } $self->_last_member_ids->@*;

  $self->group->remove_member($_) for @lost_member_ids;

  $self->_last_member_ids(\@member_ids);

  $self->group->inflate_from_membership;
}

1;
