#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;

use Hello::Tester::true;

my $loop = IO::Async::Loop->new;

{
  my $t = Hello::Tester::true->new(
    loop     => $loop,
    name     => "true",
  );

  ok($t->test->then_done(1)->get, 'always completes');
}

done_testing;
