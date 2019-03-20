#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;
use IO::Async::Stream;
use Net::EmptyPort qw(empty_port);
use MIME::Base64 qw(decode_base64);

use Hello::Tester::SMTP;

my $loop = IO::Async::Loop->new;

{
  my $port = empty_port;
  my $username = "username";
  my $password = "password";

  my $t = Hello::Tester::SMTP->new(
    loop     => $loop,
    name     => "smtp",
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
            my ($cmd, $mech, $creds) = split /\s+/, $line;
            ($cmd eq 'HELO') ?
              $s->write("250 localhost\r\n") :
            ($cmd eq 'AUTH' && $mech eq 'PLAIN' &&
              do {
                my ($u, undef, $p) = split('\0', decode_base64($creds));
                $u eq $username && $p eq $password
              }) ?
              $s->write("235 2.0.0 OK \r\n") :
            ($cmd eq 'LOGIN') ?
              $s->write("535 5.7.0 NO\r\n") :
            $s->write("500 5.5.1 BAD\r\n");
          }
          return;
        },
      );
      $loop->add($s);
      $s->write("220 localhost ESMTP\r\n");
    },
    on_listen_error => sub {},
  );

  ok($t->test->then_done(1)->else_done(0)->get, 'smtp connection succeeded when listener exists');

  my $t2 = Hello::Tester::SMTP->new(
    loop     => $loop,
    name     => "smtp auth",
    ip       => "127.0.0.1",
    port     => $port,
    username => $username,
    password => $password,
  );

  ok($t->test->then_done(1)->else_done(0)->get, 'smtp connection and authentication succeeded');

  my $t3 = Hello::Tester::SMTP->new(
    loop     => $loop,
    name     => "smtp auth fail",
    ip       => "127.0.0.1",
    port     => $port,
    username => $username,
    password => $password.'a',
  );

  ok($t->test->then_done(1)->else_done(0)->get, 'smtp connection succeeded but authentication failed');
}

done_testing;
