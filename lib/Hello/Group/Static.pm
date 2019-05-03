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

has world => ( is => 'ro', isa => class_type('Hello::World'), required => 1 );

has members => (
  is      => 'ro',
  isa     => ArrayRef[class_type('Hello::Group::Static::Member')],
  default => sub { [] },
  coerce  => sub {
    [ map { blessed $_ ? $_ : Hello::Group::Static::Member->new(id => delete $_->{id}, args => $_ ) } $_[0]->@* ]
  },
);

sub inflate {
  my ($self) = @_;

  for my $member ($self->members->@*) {
    my $member_args = $member->args;

    for my $id (keys $self->tester->%*) {
      my $config = $self->tester->{$id} // {};

      my %member_config = (%$config, %$member_args);
      my $interval = $member_config{interval} // $self->default_interval;
      my $timeout  = $member_config{timeout}  // $self->default_timeout;

      my $tester_id = join ':', $id, $self->id, $member->id;

      my $tester = Hello::Config::Tester->new(
        world => $self->world,
        class => $config->{class},
        id    => $tester_id,
        args  => {
          defined_kv(interval => $interval),
          defined_kv(timeout  => $timeout),
          map { $_ => $member_config{$_} }
            grep { ! m/^(?:world|class|args)$/ }
              keys %member_config,
        },
      );

      $tester->inflate;
    }
  }
}


package Hello::Group::Static::Member;

use Moo;
use Types::Standard qw(Str HashRef);

has id   => ( is => 'ro', isa => Str, required => 1 );
has args => ( is => 'ro', isa => HashRef, default => sub { {} } );

1;
