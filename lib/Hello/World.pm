package Hello::World;

use 5.020;
use warnings;
use strict;
use experimental qw(postderef);

use Moo;
use Types::Standard qw(ArrayRef);
use Type::Utils qw(class_type role_type);

use Date::Format qw(time2str);

use Future;
use Future::Utils qw(try_repeat);

has loop => ( is => 'ro', isa => class_type('IO::Async::Loop'), required => 1 );

has collectors => ( is => 'ro', isa => ArrayRef[role_type('Hello::Collector')], default => sub { [] } );
has testers => ( is => 'ro', isa => ArrayRef[role_type('Hello::Tester')], default => sub { [] } );

sub go {
  my ($self) = @_;

  Future->wait_all(
    map {
      my $tester = $_;
      try_repeat {
        $tester->logger->log("starting");
        $tester->test_result
          ->then(sub {
            my ($result) = @_;
            $self->_handle_result($tester, $result);
            $self->_schedule_next($tester, $result);
          })
      } while => sub { 1 };
    } $self->testers->@*
  );
}

sub _handle_result {
  my ($self, $tester, $result) = @_;
  $tester->logger->log(["result: %s (%s) [%.2fs]", $result->state, $result->reason, $result->elapsed]);
  $_->collect($result) for $self->collectors->@*;
}

sub _schedule_next {
  my ($self, $tester, $result) = @_;

  my $wait_time = int(.5 + $tester->interval - $result->elapsed);

  if ($wait_time < 0) {
    my $now = time;
    my $interval = $tester->interval;

    my $next_time = int($result->start);
    my $skipped = 0;
    while ($next_time < $now) {
      $next_time += $interval;
      $skipped++;
    }

    $wait_time = $next_time - $now;

    $tester->logger->log("WARNING: last run took longer than interval $interval; skipped $skipped tests");
  }

  $tester->logger->log(["next run in %ds, at %s", $wait_time, time2str("%Y-%m-%dT%H:%M:%S", time() + $wait_time)]);

  $self->loop->delay_future(after => $wait_time);
}

1;
