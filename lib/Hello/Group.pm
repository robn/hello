package Hello::Group;

use 5.020;
use Moo::Role;
use experimental qw(postderef);

use Types::Standard qw(Int Str Bool HashRef);

has id => ( is => 'ro', isa => Str, required => 1 );

has default_interval => ( is => 'ro', isa => Int, default => sub { 120 } );
has default_timeout  => ( is => 'ro', isa => Int, default => sub { 30 } );

has tester => (
  is      => 'ro',
  isa     => HashRef[],   # XXX HashRef[class_type('Hello::Config::Tester'] ?
  default => sub { {} },
);

requires qw(inflate);

1;
