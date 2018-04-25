#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;
use Test::Future;

use IO::Async::Loop;

use Hello::Tester::false;

my $loop = IO::Async::Loop->new;

no_pending_futures {
  my $t = Hello::Tester::false->new(
    loop     => $loop,
    name     => "false",
  );

  ok($t->test->else_done(1)->get, 'always fails');
} 'no futures left behind';

done_testing;
