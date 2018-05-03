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
    name     => "tco",
    ip       => "127.0.0.1",
    port     => $port,
    banner   => "^HELLO",
  );

  ok($t->test->else_done(1)->get, "connection failed when listener doesn't exist");

  $loop->listen(
    addr => {
      family   => 'inet',
      socktype => 'stream',
      ip       => '127.0.0.1',
      port     => $port,
    },
    on_stream => sub {
      my ($stream) = @_;
      $stream->configure(
        on_read => sub {},
      );
      $loop->add($stream);
      $stream->write("HELLO WORLD\r\n");
      $stream->close;
    },
    on_listen_error => sub {},
  );

  ok($t->test->then_done(1)->else_done(0)->get, 'connection succeeded when listener exists');
} 'no futures left behind';

done_testing;
