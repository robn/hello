package Hello::Result;

use 5.020;
use warnings;
use strict;

use Moo;
use Types::Standard qw(Str Enum Num Bool);
use Type::Utils qw(role_type);

has type => ( is => 'ro', isa => Str, required => 1 );
has name => ( is => 'ro', isa => Str, required => 1 );

has state => ( is => 'ro', isa => Enum[qw(SUCCESS FAIL TIMEOUT)], required => 1 );

has reason => ( is => 'ro', isa => Str, default => sub { '' } );

has start   => ( is => 'ro', isa => Num, required => 1 );
has elapsed => ( is => 'ro', isa => Num, required => 1 );

has is_success => ( is => 'lazy', isa => Bool, default => sub { shift->state eq 'SUCCESS' } );
has is_fail    => ( is => 'lazy', isa => Bool, default => sub { shift->state eq 'FAIL'    } );
has is_timeout => ( is => 'lazy', isa => Bool, default => sub { shift->state eq 'TIMEOUT' } );

has description => (
  is => 'lazy',
  isa => Str,
  default => sub {
    my ($self) = @_;
    sprintf "result: %s (%s) [%.2fs]", $self->state, $self->reason, $self->elapsed;
  },
);

1;
