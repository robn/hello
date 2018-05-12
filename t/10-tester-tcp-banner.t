#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;
use Net::EmptyPort qw(empty_port);

use Hello::Tester::tcp_banner;

my $loop = IO::Async::Loop->new;

{
  my $port = empty_port;

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

  my $t2 = Hello::Tester::tcp_banner->new(
    loop   => $loop,
    name   => "tcp_banner",
    ip     => "127.0.0.1",
    port   => $port,
    banner => "^HELLO",
  );
  ok($t2->test->then_done(1)->else_done(0)->get, 'connection succeeded with matching banner');

  my $t3 = Hello::Tester::tcp_banner->new(
    loop   => $loop,
    name   => "tcp_banner fail",
    ip     => "127.0.0.1",
    port   => $port,
    banner => "^HELLNO",
  );
  ok($t3->test->then_done(0)->else_done(1)->get, 'connection succeeded with mismatched banner');
}

done_testing;
