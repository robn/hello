#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;
use File::Temp qw(tempdir tempfile);

use Hello::Tester::SocketBanner;

my $loop = IO::Async::Loop->new;

{
  my $tempdir = tempdir(UNLINK => 1);
  my (undef, $path) = tempfile(OPEN => 0);

  $loop->listen(
    addr => {
      family   => 'unix',
      socktype => 'stream',
      path     => $path,
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

  my $t2 = Hello::Tester::SocketBanner->new(
    loop   => $loop,
    id     => "socket_banner",
    path   => $path,
    banner => "^HELLO",
  );
  ok($t2->test->then_done(1)->else_done(0)->get, 'connection succeeded with matching banner');

  my $t3 = Hello::Tester::SocketBanner->new(
    loop   => $loop,
    id     => "socket_banner fail",
    path   => $path,
    banner => "^HELLNO",
  );
  ok($t3->test->then_done(0)->else_done(1)->get, 'connection succeeded with mismatched banner');
}

done_testing;
