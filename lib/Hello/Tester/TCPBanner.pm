package Hello::Tester::TCPBanner;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::TCP';
with 'Hello::Tester::Role::Banner';

use Types::Standard qw(Str);

sub description { shift->_description }
has _description => (
  is  => 'lazy',
  isa => Str,
  default => sub {
    my ($self) = @_;
    my $str = sprintf "TCP connect to %s:%s, banner match: %s ", $self->ip, $self->port, $self->banner;
  },
);

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_banner($self->$orig(@_));
};

1;

