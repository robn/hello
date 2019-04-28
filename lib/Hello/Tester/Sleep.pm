package Hello::Tester::Sleep;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Str Int);

sub description { shift->_description }
has _description => (
  is  => 'lazy',
  isa => Str,
  default => sub { sprintf "sleep %ds", shift->sleep },
);

has sleep => ( is => 'ro', isa => Int, required => 1 );

sub test {
  my ($self) = @_;

  return $self->loop->delay_future(after => $self->sleep);
}

1;
