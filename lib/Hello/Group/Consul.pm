package Hello::Group::Consul;

use 5.020;
use warnings;
use strict;
use experimental qw(postderef);

use Moo;
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

has _index => ( is => 'rw', isa => Int, default => 0);

has _registered_testers => ( is => 'rw', default => sub { {} } );

sub inflate {
  my ($self) = @_;
  $self->_catalog->service(
    $self->service,
    index => $self->_index,
    wait => '10s',
    cb => sub { $self->_change_handler(@_) },
    error_cb => sub { $self->_error_handler(@_) },
  );
}

sub _change_handler {
  my ($self, $nodes, $meta) = @_;

  # no change, timeout or other thing, just go back to sleep
  if ($meta->index == $self->_index) {
    $self->inflate;
    return;
  }

  $self->logger->log(["consul: catalog change (index %d -> %d)", $self->_index, $meta->index]);
  $self->_index($meta->index);

  my %new_registered;

  for my $node ($nodes->@*) {

    for my $id (keys $self->tester->%*) {
      my $config = $self->tester->{$id} // {};

      my %member_config = %$config;
      $member_config{ip} = $node->address;

      my $tester_id = join ':', $id, $self->id, $node->node, $node->name;

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

  $self->inflate;
}

sub _error_handler {
  my ($self, $msg) = @_;

  $self->logger->log("consul: error: $msg");
  $self->logger->log("consul: will retry in 10s");

  my $timer = IO::Async::Timer::Countdown->new(
    delay => 10,
    on_expire => sub {
      $self->inflate;
    },
  );
  $timer->start;
  $self->world->loop->add($timer);
}

1;
