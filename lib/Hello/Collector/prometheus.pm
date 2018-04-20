package Hello::Collector::prometheus;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Collector';

use Types::Standard qw(Str Int);

has ip   => ( is => 'ro', isa => Str, required => 1 );
has port => ( is => 'ro', isa => Int, required => 1 );

sub collect {
  my ($self, $result) = @_;

  say "collected";
}

1;
