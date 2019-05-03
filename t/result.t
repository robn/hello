#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;

use Hello::Tester::True;
use Hello::Tester::False;
use Hello::Tester::Sleep;

my $loop = IO::Async::Loop->new;

{
  my $t = Hello::Tester::True->new(
    loop     => $loop,
    id       => "true",
  );

  my $r = $t->test_result->get;
  is(ref $r, 'Hello::Result', 'result is properly blesed');
  ok($r->is_success, 'result is in SUCCESS state');
}

{
  my $t = Hello::Tester::False->new(
    loop     => $loop,
    id       => "false",
  );

  my $r = $t->test_result->get;
  is(ref $r, 'Hello::Result', 'result is properly blesed');
  ok($r->is_fail, 'result is in FAIL state');
}

{
  my $t = Hello::Tester::Sleep->new(
    loop     => $loop,
    id       => "sleep 10",
    sleep    => 10,
    timeout  => 2,
  );

  my $r = $t->test_result->get;
  is(ref $r, 'Hello::Result', 'result is properly blesed');
  ok($r->is_timeout, 'result is in TIMEOUT state');
}

done_testing;
