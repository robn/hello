package Hello::World;

use 5.020;
use warnings;
use strict;
use experimental qw(postderef);

use Moo;
use Types::Standard qw(ArrayRef Dict Str ClassName slurpy);
use Type::Utils qw(class_type role_type);
use Type::Params qw(compile);

use Carp qw(croak);
use TOML qw(from_toml);
use Module::Runtime qw(require_module);
use Defined::KV;

use Future;
use Future::Utils qw(try_repeat);

use Hello::Logger '$Logger';

has loop => ( is => 'ro', isa => class_type('IO::Async::Loop'), required => 1 );

has collectors => ( is => 'ro', isa => ArrayRef[role_type('Hello::Collector')], default => sub { [] } );
has testers => ( is => 'ro', isa => ArrayRef[role_type('Hello::Tester')], default => sub { [] } );

sub from_config {
  state $check = compile(
    ClassName,
    slurpy Dict[
      loop     => class_type('IO::Async::Loop'),
      filename => Str,
    ],
  );
  my ($class, $args) = $check->(@_);

  my ($loop, $filename) = $args->@{qw(loop filename)};

  my ($config, $err) = from_toml(do { local (@ARGV, $/) = ($filename); <> }); # XXX not found
  croak "couldn't parse TOML config file '$filename': $err" unless $config;

  my $default_config = delete $config->{tester}->{_defaults_} // {};
  my $default_interval = delete $default_config->{interval};
  my $default_timeout  = delete $default_config->{timeout};

  my @collectors;

  for my $collector_type (keys $config->{collector}->%*) {
    my $collector_config = delete $config->{collector}->{$collector_type} // {};

    my $collector_package = "Hello::Collector::$collector_type";
    require_module($collector_package); # XXX fail

    my $collector = $collector_package->new(
      loop => $loop,
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
        loop     => $loop,
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
    loop => $loop,
    collectors => \@collectors,
    testers => \@testers,
  );
}

sub go {
  my ($self) = @_;

  Future->wait_all(
    map {
      my $tester = $_;
      try_repeat {
        my $Logger = $Logger->proxy({ proxy_prefix => $tester->name.': ' });

        $Logger->log("starting");

        $tester->test_result
          ->then(sub {
            my ($result) = @_;

            $Logger->log(["result: %s (%s) [%.2fs]", $result->state, $result->reason, $result->elapsed]);

            $_->collect($result) for $self->collectors->@*;

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

              $Logger->log("WARNING: last run took longer than interval $interval; skipped $skipped tests");
            }

            $Logger->log(["next run in %ds, at %s", $wait_time, scalar localtime(time() + $wait_time)]);

            $self->loop->delay_future(after => $wait_time);
          })
      } while => sub { 1 };
    } $self->testers->@*
  );
}

1;
