package Hello::Config::Collector;

use 5.020;
use Moo;
use experimental qw(postderef);

use Types::Standard qw(Str HashRef);
use Type::Utils qw(class_type);

use Module::Runtime qw(require_module);

use Hello::World;
use Hello::Logger '$Logger';

has world => ( is => 'ro', isa => class_type('Hello::World'), required => 1 );
has class => ( is => 'ro', isa => Str,                        required => 1 );
has id    => ( is => 'ro', isa => Str,                        required => 1 );

has args  => ( is => 'ro', isa => HashRef, default => sub { {} } );

sub inflate {
  my ($self) = @_;
  require_module($self->class); # XXX fail

  my $collector = $self->class->new(
    loop => $self->world->loop,
    id   => $self->id,
    $self->args->%*,
  );

  $self->world->add_collector($collector);
}

1;
