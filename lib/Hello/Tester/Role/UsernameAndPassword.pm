package Hello::Tester::Role::UsernameAndPassword;

use 5.020;
use warnings;
use strict;

use Moo::Role;
use Types::Standard qw(Str);

use Carp qw(croak);

has username => ( is => 'ro', isa => Str );
has password => ( is => 'ro', isa => Str );

sub BUILD {
  my ($self, $args) = @_;
  croak "username supplied without password"
    if defined $self->username && !defined $self->password;
  croak "password supplied without username"
    if defined $self->password && !defined $self->username;
}

1;
