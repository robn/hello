package Hello::Tester::tcp_tls;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::tcp';
with 'Hello::Tester::Role::TLS';

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_tls($self->$orig(@_));
};

1;

