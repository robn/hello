#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;
use File::Temp qw(tempdir tempfile);

use Hello::Tester::Socket;

my $loop = IO::Async::Loop->new;

{
  my $tempdir = tempdir(UNLINK => 1);
  my (undef, $path) = tempfile(OPEN => 0);

  my $t = Hello::Tester::Socket->new(
    loop => $loop,
    id   => "socket",
    path => $path,
  );

  ok($t->test->else_done(1)->get, "connection failed when listener doesn't exist");

  $loop->listen(
    addr => {
      family   => 'unix',
      socktype => 'stream',
      path     => $path,
    },
    on_stream => sub {},
    on_listen_error => sub {},
  );

  ok($t->test->then_done(1)->else_done(0)->get, 'connection succeeded when listener exists');
}

done_testing;
