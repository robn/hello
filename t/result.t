#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;
use Test::Deep;

use IO::Async::Loop;

use Hello::Tester::True;
use Hello::Tester::False;
use Hello::Tester::Sleep;

my $loop = IO::Async::Loop->new;

my $tags = {
  foo => 'bar',
  baz => 'quux',
};

{
  my $t = Hello::Tester::True->new(
    loop     => $loop,
    id       => "true",
    tags     => $tags,
  );

  my $r = $t->test_result->get;
  is(ref $r, 'Hello::Result', 'result is properly blesed');
  ok($r->is_success, 'result is in SUCCESS state');

  cmp_deeply($tags, $r->tags, 'result tags are present and correct');
}

{
  my $t = Hello::Tester::False->new(
    loop     => $loop,
    id       => "false",
    tags     => $tags,
  );

  my $r = $t->test_result->get;
  is(ref $r, 'Hello::Result', 'result is properly blesed');
  ok($r->is_fail, 'result is in FAIL state');

  cmp_deeply($tags, $r->tags, 'result tags are present and correct');
}

{
  my $t = Hello::Tester::Sleep->new(
    loop     => $loop,
    id       => "sleep 10",
    sleep    => 10,
    timeout  => 2,
    tags     => $tags,
  );

  my $r = $t->test_result->get;
  is(ref $r, 'Hello::Result', 'result is properly blesed');
  ok($r->is_timeout, 'result is in TIMEOUT state');

  cmp_deeply($tags, $r->tags, 'result tags are present and correct');
}

done_testing;
