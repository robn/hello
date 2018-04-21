package Hello::Collector;

use 5.020;
use warnings;
use strict;

use Moo::Role;
use Type::Utils qw(class_type);

has loop => ( is => 'ro', isa => class_type('IO::Async::Loop'), required => 1 );

requires qw(collect);

sub init { }

1;
