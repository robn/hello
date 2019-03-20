#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;
use IO::Async::Stream;
use Net::EmptyPort qw(empty_port);

use Hello::Tester::IMAP;

my $loop = IO::Async::Loop->new;

{
  my $port = empty_port;
  my $username = "username";
  my $password = "password";

  my $t = Hello::Tester::IMAP->new(
    loop     => $loop,
    name     => "imap",
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
    on_stream => sub {
      my ($s) = @_;
      $s->configure(
        on_read => sub {
          my ($s, $buf, $eof) = @_;
          $s->close, return if $eof;
          while ($$buf =~ s/^(.*\n)//) {
            my $line = $1;
            my ($tag, $cmd, $u, $p) = split /\s+/, $line;
            ($cmd eq 'LOGIN' && $u eq $username && $p eq $password) ?
              $s->write("$tag OK\r\n") :
            ($cmd eq 'LOGIN') ?
              $s->write("$tag NO\r\n") :
            $s->write("$tag BAD\r\n");
          }
          return;
        },
      );
      $loop->add($s);
      $s->write("* OK IMAP4 ready\r\n");
    },
    on_listen_error => sub {},
  );

  ok($t->test->then_done(1)->else_done(0)->get, 'imap connection succeeded when listener exists');

  my $t2 = Hello::Tester::IMAP->new(
    loop     => $loop,
    name     => "imap auth",
    ip       => "127.0.0.1",
    port     => $port,
    username => $username,
    password => $password,
  );

  ok($t->test->then_done(1)->else_done(0)->get, 'imap connection and authentication succeeded');

  my $t3 = Hello::Tester::IMAP->new(
    loop     => $loop,
    name     => "imap auth fail",
    ip       => "127.0.0.1",
    port     => $port,
    username => $username,
    password => $password.'a',
  );

  ok($t->test->then_done(1)->else_done(0)->get, 'imap connection succeeded but authentication failed');
}

done_testing;
