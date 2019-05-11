#!/usr/bin/env perl

use 5.020;
use warnings;
use strict;
use experimental qw(postderef);

use Test::More;
use Test::Deep;

use IO::Async::Loop;

use Hello::World;
use Hello::Group::Static;

my $loop = IO::Async::Loop->new;
my $world = Hello::World->new(loop => $loop);

my $group = Hello::Group::Static->new(
  world   => $world,
  id      => "group1",
  members => [
    { id => "member1", interval => 5 },
    { id => "member2" },
    { id => "member3", timeout => 20 },
  ],
  template => {
    tester1 => { class => "Hello::Tester::True",  interval => 10 },
    tester2 => { class => "Hello::Tester::False", timeout => 10 },
    tester3 => { class => "Hello::Tester::Sleep", sleep => 30 },
  },
);
$group->start;

cmp_deeply(
  $world->_testers,
  {
    'tester1:group1:member1' => all(
      isa('Hello::Tester::True'),
      methods(interval => 5, timeout => 30),
    ),
    'tester1:group1:member2' => all(
      isa('Hello::Tester::True'),
      methods(interval => 10, timeout => 30),
    ),
    'tester1:group1:member3' => all(
      isa('Hello::Tester::True'),
      methods(interval => 10, timeout => 20),
    ),
    'tester2:group1:member1' => all(
      isa('Hello::Tester::False'),
      methods(interval => 5, timeout => 10),
    ),
    'tester2:group1:member2' => all(
      isa('Hello::Tester::False'),
      methods(interval => 120, timeout => 10),
    ),
    'tester2:group1:member3' => all(
      isa('Hello::Tester::False'),
      methods(interval => 120, timeout => 20),
    ),
    'tester3:group1:member1' => all(
      isa('Hello::Tester::Sleep'),
      methods(interval => 5, timeout => 30),
    ),
    'tester3:group1:member2' => all(
      isa('Hello::Tester::Sleep'),
      methods(interval => 120, timeout => 30),
    ),
    'tester3:group1:member3' => all(
      isa('Hello::Tester::Sleep'),
      methods(interval => 120, timeout => 20),
    ),
  },
  'testers for all members x templates were composed correctly'
);

done_testing;
