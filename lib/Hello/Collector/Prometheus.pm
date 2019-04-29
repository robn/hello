package Hello::Collector::Prometheus;

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
use Prometheus::Tiny 0.002;

has ip   => ( is => 'ro', isa => Str, required => 1 );
has port => ( is => 'ro', isa => Int, required => 1 );

has _prom_client => ( is => 'ro', isa => class_type('Prometheus::Tiny'),
                      default => sub {
                        my $prom = Prometheus::Tiny->new;

                        for my $metric (qw(total success_total fail_total timeout_total)) {
                          $prom->declare(
                            "hello_test_$metric",
                            help => $metric, # XXX
                            type => 'counter',
                          );
                        }

                        for my $metric (qw(run_time_seconds last_time last_success_time last_fail_time last_timeout_time)) {
                          $prom->declare(
                            "hello_test_$metric",
                            help => $metric, # XXX
                            type => 'gauge',
                          );
                        }

                        $prom->declare(
                          'hello_up',
                          help => 'Set to 1 if hello is running',
                          type => 'gauge',
                        );

                        $prom
                      },
                    );

sub init {
  my ($self) = @_;

  $self->_prom_client->set(hello_up => 1);

  my $Logger = $Logger->proxy({ proxy_prefix => "prometheus collector: " });

  my $http = Net::Async::HTTP::Server::PSGI->new(
    app => Plack::Middleware::AccessLog->wrap(
      $self->_prom_client->psgi,
      logger => sub {
        my $msg = join '', @_;
        chomp $msg;
        $Logger->log("access: $msg");
      },
    ),
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

  my $prom = $self->_prom_client;

  my %labels = ( id => $result->id );

  my $time = int($result->start + $result->elapsed);

  $prom->inc('hello_test_total', \%labels);
  $prom->set('hello_test_last_time', $time, \%labels);

  if ($result->is_success) {
    $prom->inc('hello_test_success_total', \%labels);
    $prom->set('hello_test_last_success_time', $time, \%labels);
  }
  elsif ($result->is_fail) {
    $prom->inc('hello_test_fail_total', \%labels);
    $prom->set('hello_test_last_fail_time', $time, \%labels);
  }
  elsif ($result->is_timeout) {
    $prom->inc('hello_test_timeout_total', \%labels);
    $prom->set('hello_test_last_timeout_time', $time, \%labels);
  }
  else {
    die "result in an impossible state?";
  }

  $prom->set('hello_test_run_time_seconds', $result->elapsed, \%labels);
}

1;
