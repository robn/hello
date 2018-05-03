package Hello::Tester::http;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Str);

use Net::Async::HTTP;

has url => ( is => 'ro', isa => Str, required => 1 );

sub test {
  my ($self) = @_;

  my $http = Net::Async::HTTP->new;
  $self->loop->add($http);

  $http->do_request(uri => $self->url)->then(sub {
    my ($res) = @_;
    $self->loop->remove($http);
    $res->is_success ? $self->loop->new_future->done_later : $self->loop->new_future->fail_later($res->status_line);
  })->else(sub {
    $self->loop->remove($http);
    $self->loop->new_future->fail_later("HTTP request failed");
  });
}

1;
