package Hello::Tester::socket_banner;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::socket';
with 'Hello::Tester::Role::Banner';

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_banner($self->$orig(@_));
};

1;

