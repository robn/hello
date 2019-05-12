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

my $tc1 = eval { Test::Consul->start };
plan(skip_all => "consul test environment not available") unless $tc1;

my $tc2 = Test::Consul->start;
$tc1->wan_join($tc2);

my $dc1 = $tc1->datacenter;
my $dc2 = $tc2->datacenter;
my $node1 = $tc1->node_name;
my $node2 = $tc2->node_name;

my $c1_port = $tc1->port;
my $c2_port = $tc2->port;

my $c1 = Consul->new(port => $c1_port);
my $c2 = Consul->new(port => $c2_port);

my $loop = IO::Async::Loop->new;
testing_loop($loop);

my $world = Hello::World->new(loop => $loop);

my $group = Hello::Group::Consul->new(
  world        => $world,
  id           => "group1",
  service      => "testservice",
  all_datacenters => 1,
  _consul_port => $c1_port,

  template => {
    ping => { class => "Hello::Tester::True" },
  },
);
$group->start;

$c1->agent->service_register(
  Consul::Service->new(
    name => "testservice",
  )
);

wait_for { scalar keys($world->_testers->%*) > 0 };
is(scalar keys($world->_testers->%*), 1, "testers created after registering service");

cmp_deeply(
  $world->_testers,
  {
    "ping:group1:$dc1:$node1:testservice" => isa('Hello::Tester::True'),
  },
  'testers for all members x templates were composed correctly'
);

$c2->agent->service_register(
  Consul::Service->new(
    name => "testservice",
  )
);

wait_for { scalar keys($world->_testers->%*) > 1 };
is(scalar keys($world->_testers->%*), 2, "testers created after registering service");

cmp_deeply(
  $world->_testers,
  {
    "ping:group1:$dc1:$node1:testservice" => isa('Hello::Tester::True'),
    "ping:group1:$dc2:$node2:testservice" => isa('Hello::Tester::True'),
  },
  'testers for all members x templates were composed correctly'
);

done_testing;
