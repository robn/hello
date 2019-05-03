#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;

use Hello::Tester::Ping;

my $loop = IO::Async::Loop->new;

{
  my $t = Hello::Tester::Ping->new(
    loop    => $loop,
    id      => "ping",
    ip      => "127.0.0.1",
  );

  ok($t->test->then_done(1)->else_done(0)->get, "ping to localhost succeeds");

  my $t2 = Hello::Tester::Ping->new(
    loop    => $loop,
    id      => "ping fail",
    ip      => "126.0.0.1",
    timeout => 5,
  );

  ok($t2->test->then_done(0)->else_done(1)->get, "ping to nowhere times out");
}

done_testing;
