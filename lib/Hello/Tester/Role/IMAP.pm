package Hello::Tester::Role::IMAP;

use 5.020;
use warnings;
use strict;

use Moo::Role;
use Types::Standard qw(Str);

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

sub wrap_imap {
  my ($self, $f) = @_;
  $f->then(sub {
    my ($h) = @_;
    my $s = IO::Async::Stream->new(read_handle => $h, write_handle => $h, on_read => sub {});
    $self->loop->add($s);
    $s->read_until(qr/\r\n/)
    ->then(sub {
      my ($line) = @_;
      $line =~ m/^\* OK / ?
        Future->done :
        Future->fail("banner not ok: $line")
    })->then(sub {
      return Future->done unless $self->username;
      $s->write(". LOGIN ".$self->username." ".$self->password."\r\n");
    })->then(sub {
      return Future->done unless $self->username;
      $s->read_until(qr/\r\n/);
    })->then(sub {
      my ($line) = @_;
      return Future->done unless $self->username;
      $line =~ m/^\. OK / ?
        Future->done :
        Future->fail("login response not ok: $line");
    })
  });
};

1;
