package Hello::Config::Tester;

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

has config => ( is => 'ro', isa => HashRef, default => sub { {} } );

has tags => ( is => 'ro', isa => HashRef[Str], default => sub { {} } );

sub inflate {
  my ($self) = @_;

  eval {
    require_module($self->class);
  };
  if (my $err = $@) {
    $Logger->log(["couldn't require tester module %s: %s", $self->class, $err]);
    return;
  }

  my $tester = eval {
    $self->class->new(
      loop => $self->world->loop,
      id   => $self->id,
      tags => $self->tags,
      $self->config->%*,
    );
  };
  if (my $err = $@) {
    $Logger->log(["couldn't instantiate tester module %s (for %s): %s", $self->class, $self->id, $err]);
    return;
  }

  $self->world->add_tester($tester);
}

1;

