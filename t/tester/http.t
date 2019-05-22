#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;
use Net::EmptyPort qw(empty_port);
use Net::Async::HTTP::Server::PSGI;
use MIME::Base64;

use Hello::Tester::HTTP;

my $loop = IO::Async::Loop->new;

my $port = empty_port;

my $t = Hello::Tester::HTTP->new(
  loop => $loop,
  id   => "http",
  url  => "http://localhost:$port",
);

ok($t->test->else_done(1)->get, "request failed when http server doesn't exist");

my $http = Net::Async::HTTP::Server::PSGI->new(
  app => sub {
    my ($env) = @_;
    my $path = $env->{PATH_INFO};
    if ($path =~ m{/ohno$}) {
      return [ 404, [], [] ];
    }
    if ($path =~ m{/headers$}) {
      if (($env->{HTTP_X_FOO} || '') eq 'bar') {
        return [ 200, [], [] ];
      }
      return [ 400, [], [] ];
    }
    if ($path =~   m/auth$/) {
      if (($env->{HTTP_AUTHORIZATION} || '') eq 'Basic '.encode_base64("someuser:somepass", "")) {
        return [ 200, [], [] ];
      }
      return [ 403, [], [] ];
    }
    return [ 200, [], [] ];
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

my $t404 = Hello::Tester::HTTP->new(
  loop => $loop,
  id   => "http 404",
  url  => "http://localhost:$port/ohno",
);

ok($t404->test->else_done(1)->get, "request failed when endpoint not found");

my $th = Hello::Tester::HTTP->new(
  loop    => $loop,
  id      => "http headers",
  url     => "http://localhost:$port/headers",
  headers => {
    'X-Foo' => 'bar',
  },
);

ok($th->test->then_done(1)->get, "request with headers was passed correctly");

my $th400 = Hello::Tester::HTTP->new(
  loop => $loop,
  id   => "http no headers",
  url  => "http://localhost:$port/headers",
);

ok($th400->test->else_done(1)->get, "request with headers was passed correctly");

my $ta = Hello::Tester::HTTP->new(
  loop     => $loop,
  id       => "http auth",
  url      => "http://localhost:$port/auth",
  username => "someuser",
  password => "somepass",
);

ok($ta->test->then_done(1)->get, "request with auth was passed correctly");

my $ta403 = Hello::Tester::HTTP->new(
  loop     => $loop,
  id       => "http no auth",
  url      => "http://localhost:$port/auth",
);

ok($ta403->test->else_done(1)->get, "request without auth was passed correctly");

done_testing;
