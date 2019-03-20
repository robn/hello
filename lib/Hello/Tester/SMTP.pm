package Hello::Tester::SMTP;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::TCP';
with 'Hello::Tester::Role::SMTP';

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_smtp($self->$orig(@_));
};

1;
