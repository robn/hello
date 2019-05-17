package Hello::Group::Static;

use 5.020;
use Moo;
use experimental qw(postderef);

with 'Hello::Group';

use Types::Standard qw(ArrayRef);
use Type::Utils qw(class_type);

use Scalar::Util qw(blessed);
use Defined::KV;

use Hello::World;

has members => (
  is      => 'ro',
  isa     => ArrayRef[class_type('Hello::Group::Member')],
  default => sub { [] },
  coerce  => sub {
    [ map { blessed $_ ? $_ : Hello::Group::Member->new(
                                id     => delete $_->{id},
                                defined_kv(tags => delete $_->{tags}),
                                config => $_ ) } $_[0]->@* ]
  },
);

sub start {
  my ($self) = @_;
  $self->add_member($_) for $self->members->@*;
  $self->inflate_from_membership;
}

1;
