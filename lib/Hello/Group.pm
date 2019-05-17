package Hello::Group;

use 5.020;
use Moo::Role;
use experimental qw(postderef);

use Types::Standard qw(Int Str Bool HashRef);
use Type::Utils qw(class_type);

use Scalar::Util qw(blessed);

use Hello::Config::Tester;

has world => ( is => 'ro', isa => class_type('Hello::World'), required => 1 );

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

has logger => (
  is => 'lazy',
  default => sub {
    my ($self) = @_;
    Hello::Logger->current_logger->proxy({
      proxy_prefix => $self->id.': ',
    });
  },
);

has _members => (
  is      => 'ro',
  isa     => HashRef[class_type('Hello::Group::Member')],
  default => sub { {} },
);
sub add_member {
  my ($self, $member) = @_;
  $self->_members->{$member->id} = $member;
}
sub remove_member {
  my ($self, $id) = @_;
  delete $self->_members->{$id};
}

has _registered_testers => ( is => 'rw', default => sub { {} } );

sub inflate_from_membership {
  my ($self) = @_;

  my %new_registered;

  for my $member (values $self->_members->%*) {
    my $member_config = $member->config;

    for my $template_id (keys $self->template->%*) {
      my $template = $self->template->{$template_id};

      my %final_config = (
        interval => $self->default_interval,
        timeout  => $self->default_timeout,
        $template->config->%*,
        %$member_config
      );

      my $tester_id = join ':', $template_id, $self->id, $member->id;

      my $tester = Hello::Config::Tester->new(
        world   => $self->world,
        class   => $template->class,
        id      => $tester_id,
        tags    => $member->tags,
        config  => {
          map { $_ => $final_config{$_} }
            grep { ! m/^(?:world|class|id|tags|config)$/ }
              keys %final_config,
        },
      );

      $tester->inflate;

      $new_registered{$tester_id} = 1;
    }
  }

  for my $tester_id (sort keys $self->_registered_testers->%*) {
    next if exists $new_registered{$tester_id};
    $self->logger->log("removing tester for lost service: $tester_id");
    $self->world->remove_tester($tester_id);
  }

  $self->_registered_testers(\%new_registered);
}

requires qw(start);


package
  Hello::Group::Template;

use Moo;
use Types::Standard qw(Str HashRef);

has class  => ( is => 'ro', isa => Str,     required => 1 );
has config => ( is => 'ro', isa => HashRef, default => sub { {} } );


package
  Hello::Group::Member;

use Moo;
use Types::Standard qw(Str HashRef);

has id     => ( is => 'ro', isa => Str, required => 1 );
has config => ( is => 'ro', isa => HashRef, default => sub { {} } );

has tags   => ( is => 'ro', isa => HashRef[Str], default => sub { {} } );


1;
