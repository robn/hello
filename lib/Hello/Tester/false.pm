package Hello::Tester::false;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

sub test {
  my ($self) = @_;

  return $self->loop->new_future->fail_later("failures gotta fail");
}

1;
