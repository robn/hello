package Hello::Tester::Socket;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Str Int);

use IO::Async::Stream;

sub description { shift->_description }
has _description => (
  is  => 'lazy',
  isa => Str,
  default => sub { sprintf "socket connect to %s", shift->path },
);

has path => ( is => 'ro', isa => Str, required => 1 );

sub test {
  my ($self) = @_;

  $self->loop->connect(
    addr => {
      family   => "unix",
      socktype => "stream",
      path     => $self->path,
    },
  );
}

1;
