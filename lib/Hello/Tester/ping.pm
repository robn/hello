package Hello::Tester::ping;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Str);

use Net::Async::Ping;

has ip => ( is => 'ro', isa => Str, required => 1 );

sub test {
  my ($self) = @_;
  Net::Async::Ping->new->ping($self->loop, $self->ip);
}

1;
