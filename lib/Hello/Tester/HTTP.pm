package Hello::Tester::HTTP;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';
with 'Hello::Tester::Role::UsernameAndPassword';

use Types::Standard qw(Str HashRef);

use Net::Async::HTTP;
use Defined::KV;

sub description { shift->_description }
has _description => (
  is  => 'lazy',
  isa => Str,
  default => sub { sprintf "HTTP GET %s", shift->url },
);

has url => ( is => 'ro', isa => Str, required => 1 );

has headers => ( is => 'ro', isa => HashRef[Str], default => sub { {} } );

sub test {
  my ($self) = @_;

  my $http = Net::Async::HTTP->new;
  $self->loop->add($http);

  $http->do_request(
    uri => $self->url,
    headers => $self->headers,
    defined_kv(user => $self->username),
    defined_kv(pass => $self->password),
  )->then(sub {
    my ($res) = @_;
    $self->loop->remove($http);
    $res->is_success ? $self->loop->new_future->done_later : $self->loop->new_future->fail_later($res->status_line);
  });
}

1;
