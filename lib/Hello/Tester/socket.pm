package Hello::Tester::socket;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Str Int);

use IO::Async::Stream;

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
