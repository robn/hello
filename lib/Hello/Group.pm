package Hello::Group;

use 5.020;
use Moo::Role;
use experimental qw(postderef);

use Types::Standard qw(Int Str Bool HashRef);
use Type::Utils qw(class_type);

use Scalar::Util qw(blessed);

has id => ( is => 'ro', isa => Str, required => 1 );

has default_interval => ( is => 'ro', isa => Int, default => sub { 120 } );
has default_timeout  => ( is => 'ro', isa => Int, default => sub { 30 } );

has template => (
  is      => 'ro',
  isa     => HashRef[class_type('Hello::Group::Template')],
  default => sub { {} },
  coerce  => sub { +{
    map {
      my $o = $_[0]->{$_};
      ($_ => (blessed $o ? $o : do {
        Hello::Group::Template->new(
          class  => delete $o->{class},
          config => $o,
        )
      }))
    } keys $_[0]->%*
  } }
);

requires qw(inflate);


package
  Hello::Group::Template;

use Moo;
use Types::Standard qw(Str HashRef);

has class  => ( is => 'ro', isa => Str,     required => 1 );
has config => ( is => 'ro', isa => HashRef, default => sub { {} } );


1;
