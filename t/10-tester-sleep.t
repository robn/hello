#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;

use Hello::Tester::Sleep;

my $loop = IO::Async::Loop->new;

{
  my $t = Hello::Tester::Sleep->new(
    loop     => $loop,
    id       => "sleep 5",
    sleep    => 5,
  );

  my $start = time();
  my $r = $t->test->then_done(1)->get;
  my $end = time();

  ok($r, 'always succeeds');
  ok($end-$start >= 5, 'slept at least 5s');
}

done_testing;
