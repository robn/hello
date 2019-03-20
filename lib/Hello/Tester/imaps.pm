package Hello::Tester::IMAPS;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::TCPTLS';
with 'Hello::Tester::Role::IMAP';

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_imap($self->$orig(@_));
};

1;
