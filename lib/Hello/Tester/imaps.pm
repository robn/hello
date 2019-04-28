package Hello::Tester::IMAPS;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::TCPTLS';
with 'Hello::Tester::Role::IMAP';

use Types::Standard qw(Str);

sub description { shift->_description }
has _description => (
  is  => 'lazy',
  isa => Str,
  default => sub {
    my ($self) = @_;
    my $str = sprintf "IMAPS connect to %s:%s", $self->ip, $self->port;
    $str .= " as ".$self->username if defined $self->username;
  },
);

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_imap($self->$orig(@_));
};

1;
