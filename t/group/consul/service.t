#!/usr/bin/env perl

use 5.020;
use warnings;
use strict;
use experimental qw(postderef);

use Test::More;
use Test::Deep;
use Test::Consul 0.005;
use Consul;

use IO::Async::Test;
use IO::Async::Loop;

use Hello::World;
use Hello::Group::Consul;

Test::Consul->skip_all_if_no_bin;

my $tc = eval { Test::Consul->start };
plan(skip_all => "consul test environment not available") unless $tc;

my $dc = $tc->datacenter;
my $node = $tc->node_name;

my $consul_port = $tc->port;

my $consul = Consul->new(port => $consul_port);

my $loop = IO::Async::Loop->new;
testing_loop($loop);

my $world = Hello::World->new(loop => $loop);

my $group = Hello::Group::Consul->new(
  world        => $world,
  id           => "group1",
  service      => "testservice",
  _consul_port => $consul_port,

  template => {
    tester1 => { class => "Hello::Tester::True",  interval => 10 },
    tester2 => { class => "Hello::Tester::False", timeout => 10 },
    tester3 => { class => "Hello::Tester::Sleep", sleep => 30 },
  },
);
$group->start;

$consul->agent->service_register(
  Consul::Service->new(
    name => "testservice",
  )
);

wait_for { scalar keys($world->_testers->%*) > 0 };
is(scalar keys($world->_testers->%*), 3, "testers created after registering service");

cmp_deeply(
  $world->_testers,
  {
    "tester1:group1:$dc:$node:testservice" => all(
      isa('Hello::Tester::True'),
      methods(interval => 10, timeout => 30),
    ),
    "tester2:group1:$dc:$node:testservice" => all(
      isa('Hello::Tester::False'),
      methods(interval => 120, timeout => 10),
    ),
    "tester3:group1:$dc:$node:testservice" => all(
      isa('Hello::Tester::Sleep'),
      methods(interval => 120, timeout => 30),
    ),
  },
  'testers for all members x templates were composed correctly'
);

done_testing;
