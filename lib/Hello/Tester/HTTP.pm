package Hello::Tester::HTTP;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Str HashRef);

use Net::Async::HTTP;

has url => ( is => 'ro', isa => Str, required => 1 );

has headers => ( is => 'ro', isa => HashRef[Str], default => sub { {} } );

sub test {
  my ($self) = @_;

  my $http = Net::Async::HTTP->new;
  $self->loop->add($http);

  $http->do_request(
    uri => $self->url,
    headers => $self->headers,
  )->then(sub {
    my ($res) = @_;
    $self->loop->remove($http);
    $res->is_success ? $self->loop->new_future->done_later : $self->loop->new_future->fail_later($res->status_line);
  });
}

1;
