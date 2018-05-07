package Hello::Tester::tcp_banner;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::tcp';
with 'Hello::Tester::Role::Banner';

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_banner($self->$orig(@_));
};

1;

