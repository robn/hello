package Hello::Tester::tcp;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Str Int);

has ip   => ( is => 'ro', isa => Str, required => 1 );
has port => ( is => 'ro', isa => Int, required => 1 );

sub test {
  my ($self) = @_;

  $self->loop->connect(
    addr => {
      family   => "inet",
      socktype => "stream",
      port     => $self->port,
      ip       => $self->ip,
    },
  );
}

1;
