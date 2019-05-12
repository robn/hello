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
  prefix       => "hello",
  _consul_port => $consul_port,

  template => {
    ping => { class => "Hello::Tester::Ping", interval => 10 },
  },
);
$group->start;

$consul->kv->put("hello/$node/testservice/ip", "127.0.0.1");

$consul->agent->service_register(
  Consul::Service->new(
    name => "testservice",
  )
);

wait_for { scalar keys($world->_testers->%*) > 0 };
is(scalar keys($world->_testers->%*), 1, "testers created after registering service");

cmp_deeply(
  $world->_testers,
  {
    "ping:group1:$dc:$node:testservice" => all(
      isa('Hello::Tester::Ping'),
      methods(interval => 10, timeout => 30, ip => '127.0.0.1'),
    ),
  },
  'testers for all members x templates were composed correctly'
);

done_testing;

