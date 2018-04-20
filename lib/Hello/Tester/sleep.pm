package Hello::Tester::sleep;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Int);

has sleep => ( is => 'ro', isa => Int, required => 1 );

sub test {
  my ($self) = @_;

  return $self->loop->delay_future(after => $self->sleep);
}

1;
