#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;
use Net::EmptyPort qw(empty_port);
use Net::Async::HTTP;

use Hello::Collector::Prometheus;
use Hello::Result;

my $loop = IO::Async::Loop->new;

my $port = empty_port;
my $uri = "http://127.0.0.1:$port/metrics";

my $c = Hello::Collector::Prometheus->new(
  loop => $loop,
  id   => "prometheus",
  ip   => "127.0.0.1",
  port => $port,
);
$c->init;

my $http = Net::Async::HTTP->new;
$loop->add($http);

subtest "metrics endpoint" => sub {
  my $res = $http->do_request(uri => $uri)->get;
  ok($res->is_success, "succeeded");
  like($res->decoded_content, qr/hello_up\s+1/, "found up metric");
};

subtest "recording a success result" => sub {
  $c->collect(Hello::Result->new(
    id      => 'test1',
    state   => 'SUCCESS',
    start   => 2,
    elapsed => 3,
  ));
  my $res = $http->do_request(uri => $uri)->get;
  my $out = $res->decoded_content;
  like($out, qr/^hello_test_total\{id="test1"}\s+1$/m, "found record");
  like($out, qr/^hello_test_success_total\{id="test1"}\s+1$/m, "found success record");
  like($out, qr/^hello_test_run_time_seconds\{id="test1"}\s+3$/m, "found run time");
  like($out, qr/^hello_test_last_time\{id="test1"}\s+5$/m, "found last end time");
  like($out, qr/^hello_test_last_success_time\{id="test1"}\s+5$/m, "found last success end time");
};

subtest "fail result" => sub {
  $c->collect(Hello::Result->new(
    id      => 'test2',
    state   => 'FAIL',
    start   => 4,
    elapsed => 5,
  ));
  my $res = $http->do_request(uri => $uri)->get;
  my $out = $res->decoded_content;
  like($out, qr/^hello_test_total\{id="test2"}\s+1$/m, "found record");
  like($out, qr/^hello_test_fail_total\{id="test2"}\s+1$/m, "found fail record");
  like($out, qr/^hello_test_run_time_seconds\{id="test2"}\s+5$/m, "found run time");
  like($out, qr/^hello_test_last_time\{id="test2"}\s+9$/m, "found last end time");
  like($out, qr/^hello_test_last_fail_time\{id="test2"}\s+9$/m, "found last fail end time");
};

subtest "timeout result" => sub {
  $c->collect(Hello::Result->new(
    id      => 'test3',
    state   => 'TIMEOUT',
    start   => 6,
    elapsed => 7,
  ));
  my $res = $http->do_request(uri => $uri)->get;
  my $out = $res->decoded_content;
  like($out, qr/^hello_test_total\{id="test3"}\s+1$/m, "found record");
  like($out, qr/^hello_test_timeout_total\{id="test3"}\s+1$/m, "found timeout record");
  like($out, qr/^hello_test_run_time_seconds\{id="test3"}\s+7$/m, "found run time");
  like($out, qr/^hello_test_last_time\{id="test3"}\s+13$/m, "found last end time");
  like($out, qr/^hello_test_last_timeout_time\{id="test3"}\s+13$/m, "found last timeout end time");
};

done_testing;
