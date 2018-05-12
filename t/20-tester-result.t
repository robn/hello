#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;

use Hello::Tester::true;
use Hello::Tester::false;
use Hello::Tester::sleep;

my $loop = IO::Async::Loop->new;

{
  my $t = Hello::Tester::true->new(
    loop     => $loop,
    name     => "true",
  );

  my $r = $t->test_result->get;
  is(ref $r, 'Hello::Result', 'result is properly blesed');
  ok($r->is_success, 'result is in SUCCESS state');
}

{
  my $t = Hello::Tester::false->new(
    loop     => $loop,
    name     => "false",
  );

  my $r = $t->test_result->get;
  is(ref $r, 'Hello::Result', 'result is properly blesed');
  ok($r->is_fail, 'result is in FAIL state');
}

{
  my $t = Hello::Tester::sleep->new(
    loop     => $loop,
    name     => "sleep 10",
    sleep    => 10,
    timeout  => 2,
  );

  my $r = $t->test_result->get;
  is(ref $r, 'Hello::Result', 'result is properly blesed');
  ok($r->is_timeout, 'result is in TIMEOUT state');
}

done_testing;
