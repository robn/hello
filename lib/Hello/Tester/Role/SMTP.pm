package Hello::Tester::Role::SMTP;

use 5.020;
use warnings;
use strict;

use Moo::Role;
use Types::Standard qw(Str);

use MIME::Base64 qw(encode_base64);
use Carp qw(croak);

has username => ( is => 'ro', isa => Str );
has password => ( is => 'ro', isa => Str );

requires qw(loop);

sub BUILD {
  my ($self, $args) = @_;
  croak "username supplied without password"
    if defined $self->username && !defined $self->password;
  croak "password supplied without username"
    if defined $self->password && !defined $self->username;
}

sub wrap_smtp {
  my ($self, $f) = @_;
  $f->then(sub {
    my ($h) = @_;
    my $s = IO::Async::Stream->new(read_handle => $h, write_handle => $h, on_read => sub {});
    $self->loop->add($s);
    $s->read_until(qr/\r\n/)
    ->then(sub {
      my ($line) = @_;
      $line =~ m/^2\d\d .*SMTP/ ?
        Future->done :
        Future->fail("banner not ok: $line")
    })->then(sub {
      $s->write("HELO hello-tester\r\n");
    })->then(sub {
      $s->read_until(qr/\r\n/);
    })->then(sub {
      my ($line) = @_;
      $line =~ m/^2\d\d / ?
        Future->done :
        Future->fail("bad response to HELO: $line")
    })->then(sub {
      return Future->done unless $self->username;
      my $auth_plain = encode_base64(join("\0", $self->username, $self->username, $self->password), '');
      $s->write("AUTH PLAIN $auth_plain\r\n");
    })->then(sub {
      return Future->done unless $self->username;
      $s->read_until(qr/\r\n/);
    })->then(sub {
      my ($line) = @_;
      $s->close_now;
      return Future->done unless $self->username;
      $line =~ m/^2\d\d / ?
        Future->done :
        Future->fail("login response not ok: $line");
    })
  });
};

1;
