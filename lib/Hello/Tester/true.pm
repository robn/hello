package Hello::Tester::true;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

sub test {
  my ($self) = @_;

  return $self->loop->new_future->done_later;
}

1;
