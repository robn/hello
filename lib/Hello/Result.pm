package Hello::Result;

use 5.020;
use warnings;
use strict;

use Moo;
use Types::Standard qw(Str Enum Num);
use Type::Utils qw(role_type);

has state => ( is => 'ro', isa => Enum[qw(SUCCESS FAIL TIMEOUT)], required => 1 );

has reason => ( is => 'ro', isa => Str, default => sub { '' } );

has start   => ( is => 'ro', isa => Num, required => 1 );
has elapsed => ( is => 'ro', isa => Num, required => 1 );

1;
