package Hello::Tester;

use 5.020;
use warnings;
use strict;

use Moo::Role;
use Types::Standard qw(Int Str Bool);
use Type::Utils qw(class_type);

use Future;
use Time::HiRes qw(gettimeofday tv_interval);

use Hello::Logger;
use Hello::Result;

has loop => ( is => 'ro', isa => class_type('IO::Async::Loop'), required => 1 );

has name => ( is => 'ro', isa => Str, required => 1 );

has interval => ( is => 'ro', isa => Int, default => sub { 120 } );
has timeout  => ( is => 'ro', isa => Int, default => sub { 30 } );

has type => ( is => 'lazy', isa => Str, default => sub { [ref(shift) =~ m/::([^:]+$)/]->[0] } );

has alive => ( is => 'rw', isa => Bool, default => sub { 0 } );

has logger => (
  is => 'lazy',
  default => sub {
    Hello::Logger->current_logger->proxy({ proxy_prefix => shift->name.': ' })
  },
);

requires qw(test);

sub test_result {
  my ($self) = @_;

  my $tv_start = [gettimeofday];

  Future->wait_any(
    Future->call(sub { $self->test })
      ->then(sub {
        return Future->done(Hello::Result->new(
          state   => 'SUCCESS',
          start   => $tv_start->[0] + $tv_start->[1] / 1_000_000,
          elapsed => tv_interval($tv_start),
          type    => $self->type,
          name    => $self->name,
        ));
      })
      ->else(sub {
        my ($exception, @details) = @_;
        return Future->done(Hello::Result->new(
          state   => 'FAIL',
          reason  => $exception ,
          start   => $tv_start->[0] + $tv_start->[1] / 1_000_000,
          elapsed => tv_interval($tv_start),
          type    => $self->type,
          name    => $self->name,
        ));
      }),
    $self->loop->timeout_future(after => $self->timeout)
      ->else(sub {
        return Future->done(Hello::Result->new(
          state   => 'TIMEOUT',
          start   => $tv_start->[0] + $tv_start->[1] / 1_000_000,
          elapsed => tv_interval($tv_start),
          type    => $self->type,
          name    => $self->name,
        ));
      }),
  )
}

1;
