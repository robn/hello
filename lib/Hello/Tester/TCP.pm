package Hello::Tester::TCP;

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
  default => sub { my ($self) = @_; sprintf "TCP connect to %s:%s", $self->ip, $self->port },
);

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
