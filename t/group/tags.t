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
    { id => "member1", tags => { foo => "bar", baz => "quux" } },
  ],
  template => {
    tester1 => { class => "Hello::Tester::True" },
  },
);
$group->start;

cmp_deeply(
  $world->_testers,
  {
    'tester1:group1:member1' => all(
      isa('Hello::Tester::True'),
      methods(tags => { foo => "bar", baz => "quux" }),
    ),
  },
  'member tags appear on composed tester',
);

done_testing;
