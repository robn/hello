#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;
use Net::EmptyPort qw(empty_port);
use Net::Async::HTTP::Server::PSGI;

use Hello::Tester::http;

my $loop = IO::Async::Loop->new;

my $port = empty_port;

my $t = Hello::Tester::http->new(
  loop => $loop,
  name => "http",
  url  => "http://localhost:$port",
);

ok($t->test->else_done(1)->get, "request failed when http server doesn't exist");

my $http = Net::Async::HTTP::Server::PSGI->new(
  app => sub {
    return [ shift->{PATH_INFO} =~ m{/ohno$} ? '404' : '200', [], [] ];
  },
);
$loop->add($http);

$http->listen(
  addr => {
    family   => 'inet',
    socktype => 'stream',
    port     => $port,
  },
  on_listen => sub {},
  on_listen_error => sub {},
);

ok($t->test->then_done(1)->get, "request succeeded when http server exists");

my $t404 = Hello::Tester::http->new(
  loop => $loop,
  name => "http 404",
  url  => "http://localhost:$port/ohno",
);

ok($t404->test->else_done(1)->get, "request failed when endpoint not found");

done_testing;
