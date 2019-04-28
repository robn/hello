package Hello::Config::Group;

use 5.020;
use Moo;
use experimental qw(postderef);

use Types::Standard qw(Str Int HashRef);
use Type::Utils qw(class_type);

use Module::Runtime qw(require_module);

use Hello::World;
use Hello::Logger '$Logger';

has world => ( is => 'ro', isa => class_type('Hello::World'), required => 1 );
has class => ( is => 'ro', isa => Str,                        required => 1 );
has id    => ( is => 'ro', isa => Str,                        required => 1 );

has default_interval => ( is => 'ro', isa => Int );
has default_timeout  => ( is => 'ro', isa => Int );

has args  => ( is => 'ro', isa => HashRef, default => sub { {} } );

sub inflate {
  my ($self) = @_;

  eval {
    require_module($self->class);
  };
  if (my $err = $@) {
    $Logger->log(["couldn't require group module %s: %s", $self->class, $err]);
    return;
  }

  my $group = $self->class->new(
    world => $self->world,
    id    => $self->id,
    $self->args->%*,
  );

  $group->inflate;
}

1;
