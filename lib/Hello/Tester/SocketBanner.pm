package Hello::Tester::SocketBanner;

use 5.020;
use warnings;
use strict;

use Moo;
extends 'Hello::Tester::Socket';
with 'Hello::Tester::Role::Banner';

use Types::Standard qw(Str);

sub description { shift->_description }
has _description => (
  is  => 'lazy',
  isa => Str,
  default => sub {
    my ($self) = @_;
    my $str = sprintf "socket connect to %s, banner match: %s ", $self->path, $self->banner;
  },
);

around test => sub {
  my ($orig, $self) = (shift, shift);
  $self->wrap_banner($self->$orig(@_));
};

1;

