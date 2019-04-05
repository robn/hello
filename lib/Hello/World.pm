package Hello::World;

use 5.020;
use Moo;
use experimental qw(postderef);

use Types::Standard qw(Object Str);
use Type::Utils qw(class_type role_type);
use Type::Params qw(compile);

use Date::Format qw(time2str);

use Future;
use Future::Utils qw(try_repeat);

use Hello::Logger '$Logger';

has loop => ( is => 'ro', isa => class_type('IO::Async::Loop'), required => 1 );

has _collectors => ( is => 'rw', default => sub { [] } );

sub add_collector {
  state $check = compile(Object, role_type('Hello::Collector'));
  my ($self, $collector) = $check->(@_);
  push $self->_collectors->@*, $collector;

  # XXX replaceable?

  $Logger->log(["added collector: %s", $collector->id]);

  $collector->init;
}

has _testers => ( is => 'rw', default => sub { {} } );

sub add_tester {
  state $check = compile(Object, role_type('Hello::Tester'));
  my ($self, $tester) = $check->(@_);

  my $testers = $self->_testers;

  if ($testers->{$tester->id}) {
    $Logger->log(["replacing existing tester: %s", $tester->id]);
    $self->remove_tester($tester->id);
  }

  $Logger->log(["added tester: %s; interval %d; timeout %d", $tester->id, $tester->interval, $tester->timeout]);

  $testers->{$tester->id} = $tester;

  $tester->alive(1);

  try_repeat {
    $tester->logger->log("starting");
    $tester->test_result
      ->then(sub {
        my ($result) = @_;
        $self->_handle_result($tester, $result);
        $self->_schedule_next($tester, $result);
      })
  } while => sub { $tester->alive };
}

sub remove_tester {
  state $check = compile(Object, Str);
  my ($self, $name) = $check->(@_);
  my $tester = delete $self->_testers->{$name};
  $tester->alive(0) if $tester;
}

sub _handle_result {
  my ($self, $tester, $result) = @_;
  $tester->logger->log($result->description);
  $_->collect($result) for $self->_collectors->@*;
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
