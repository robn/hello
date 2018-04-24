#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;
use Test::Future;

use IO::Async::Loop;

use Hello::Tester::true;

my $loop = IO::Async::Loop->new;

no_pending_futures {
  my $t = Hello::Tester::true->new(
    loop     => $loop,
    interval => 120,
    timeout  => 10,
    name     => "true",
  );

  ok($t->test->then_done(1)->get, 'always completes');
} 'no futures left behind';

done_testing;
