#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;
use Test::Future;

use IO::Async::Loop;
use Net::EmptyPort qw(empty_port);

use Hello::Tester::tcp;

my $loop = IO::Async::Loop->new;

no_pending_futures {
  my $port = empty_port;

  my $t = Hello::Tester::tcp->new(
    loop     => $loop,
    name     => "tcp",
    ip       => "127.0.0.1",
    port     => $port,
  );

  ok($t->test->else_done(1)->get, "connection failed when listener doesn't exist");

  $loop->listen(
    addr => {
      family   => 'inet',
      socktype => 'stream',
      ip       => '127.0.0.1',
      port     => $port,
    },
    on_stream => sub {},
    on_listen_error => sub {},
  );

  ok($t->test->then_done(1)->else_done(0)->get, 'connection succeeded when listener exists');
} 'no futures left behind';

done_testing;
