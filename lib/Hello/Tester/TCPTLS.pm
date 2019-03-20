package Hello::Tester::TCPTLS;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::TCP';
with 'Hello::Tester::Role::TLS';

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_tls($self->$orig(@_));
};

1;

