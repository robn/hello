package Hello::Tester::TCPTLS;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::TCP';
with 'Hello::Tester::Role::TLS';

use Types::Standard qw(Str);

sub description { shift->_description }
has _description => (
  is  => 'lazy',
  isa => Str,
  default => sub {
    my ($self) = @_;
    my $str = sprintf "TCP+TLS connect to %s:%s", $self->ip, $self->port;
  },
);

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_tls($self->$orig(@_));
};

1;

