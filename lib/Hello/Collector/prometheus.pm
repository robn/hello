package Hello::Collector::prometheus;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Collector';

use Types::Standard qw(Str Int HashRef);
use Type::Utils qw(class_type);

use Net::Async::HTTP::Server::PSGI;
use Plack::Middleware::AccessLog;
use Hello::Logger '$Logger';
use Net::Prometheus;

has ip   => ( is => 'ro', isa => Str, required => 1 );
has port => ( is => 'ro', isa => Int, required => 1 );

has _prom_client => ( is => 'ro', isa => class_type('Net::Prometheus'),
                      default => sub { Net::Prometheus->new(disable_process_collector => 1) } );

has _prom_counters => ( is => 'ro', isa => HashRef[class_type('Net::Prometheus::Counter')],
                        default => sub {
                          my $group = shift->_prom_client->new_metricgroup(
                            namespace => 'hello',
                            subsystem => 'test',
                          );
                          +{
                            map {
                              ($_ => $group->new_counter(
                                name   => $_,
                                help   => $_, # XXX
                                labels => [qw(type name)],
                              ))
                            } qw(
                              total
                              success_total
                              fail_total
                              timeout_total
                            )
                          }
                        } );

has _prom_gauges => ( is => 'ro', isa => HashRef[class_type('Net::Prometheus::Gauge')],
                        default => sub {
                          my $group = shift->_prom_client->new_metricgroup(
                            namespace => 'hello',
                            subsystem => 'test',
                          );
                          +{
                            map {
                              ($_ => $group->new_gauge(
                                name   => $_,
                                help   => $_, # XXX
                                labels => [qw(type name)],
                              ))
                            } qw(
                              run_time_seconds
                              last_time
                              last_success_time
                              last_fail_time
                              last_timeout_time
                            )
                          }
                        } );

sub init {
  my ($self) = @_;

  my $Logger = $Logger->proxy({ proxy_prefix => "prometheus collector: " });

  my $http = Net::Async::HTTP::Server::PSGI->new(
    app => Plack::Middleware::AccessLog->wrap(
      $self->_prom_client->psgi_app,
      logger => $Logger,
    )
  );
  $self->loop->add($http);

  $http->listen(
    addr => {
      family   => 'inet',
      socktype => 'stream',
      ip       => $self->ip,
      port     => $self->port,
    },
    on_listen => sub {
      $Logger->log(["listening on %s:%s", $self->ip, $self->port]);
    },
    on_listen_error => sub {
      my ($type, $err) = @_;
      $Logger->log(["couldn't %s on listen socket %s:%s: %s", $type, $self->ip, $self->port, $err]);
    },
  );
}

sub collect {
  my ($self, $result) = @_;

  my @labels = ($result->type, $result->name);

  my $counters = $self->_prom_counters;
  my $gauges = $self->_prom_gauges;

  my $time = int($result->start + $result->elapsed);

  $counters->{total}->inc(@labels);
  $gauges->{last_time}->set(@labels, $time);

  if ($result->is_success) {
    $counters->{success_total}->inc(@labels);
    $gauges->{last_success_time}->set(@labels, $time);
  }
  elsif ($result->is_fail) {
    $counters->{fail_total}->inc(@labels);
    $gauges->{last_fail_time}->set(@labels, $time);
  }
  elsif ($result->is_timeout) {
    $counters->{timeout_total}->inc(@labels);
    $gauges->{last_timeout_time}->set(@labels, $time);
  }
  else {
    die "result in an impossible state?";
  }

  $gauges->{run_time_seconds}->set(@labels, $result->elapsed);
}

1;
