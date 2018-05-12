package Hello::Tester::Role::TLS;

use 5.020;
use warnings;
use strict;

use Moo::Role;

use Types::Standard qw(Str Bool);

use IO::Async::SSL;
use Defined::KV;

has verify      => ( is => 'ro', isa => Bool, default => sub { 1 } );
has fingerprint => ( is => 'ro', isa => Str );

requires qw(loop);

sub wrap_tls {
  my ($self, $f) = @_;
  $f->then(sub {
    $self->loop->SSL_upgrade(
      handle => shift,
      SSL_verify_mode => $self->verify ? IO::Socket::SSL::SSL_VERIFY_PEER : IO::Socket::SSL::SSL_VERIFY_NONE,
    )
  });
}

1;
