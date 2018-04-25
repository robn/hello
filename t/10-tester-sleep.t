#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;
use Test::Future;

use IO::Async::Loop;

use Hello::Tester::sleep;

my $loop = IO::Async::Loop->new;

no_pending_futures {
  my $t = Hello::Tester::sleep->new(
    loop     => $loop,
    name     => "sleep 5",
    sleep    => 5,
  );

  my $start = time();
  my $r = $t->test->then_done(1)->get;
  my $end = time();

  ok($r, 'always succeeds');
  ok($end-$start >= 5, 'slept at least 5s');
} 'no futures left behind';

done_testing;
