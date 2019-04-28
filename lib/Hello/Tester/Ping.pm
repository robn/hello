package Hello::Tester::Ping;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Str);

use Net::Async::Ping;

sub description { shift->_description }
has _description => (
  is  => 'lazy',
  isa => Str,
  default => sub { sprintf "ping %s", shift->ip },
);

has ip => ( is => 'ro', isa => Str, required => 1 );

sub test {
  my ($self) = @_;
  Net::Async::Ping->new->ping($self->loop, $self->ip);
}

1;
