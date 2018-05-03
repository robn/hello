package Hello::Tester::tcp_connect;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

use Types::Standard qw(Str Int);

use IO::Async::Stream;

has ip   => ( is => 'ro', isa => Str, required => 1 );
has port => ( is => 'ro', isa => Int, required => 1 );

has banner => ( is => 'ro', isa => Str );

sub test {
  my ($self) = @_;

  my $f = $self->loop->connect(
    addr => {
      family   => "inet",
      socktype => "stream",
      port     => $self->port,
      ip       => $self->ip,
    },
  );

  if ($self->banner) {
    my $re = $self->banner;
    $f = $f->then(sub {
      my $h = IO::Async::Stream->new(read_handle => shift, on_read => sub {});
      $self->loop->add($h);
      $h->read_until(qr/$re/)->then(sub {
        my ($read, $eof) = @_;
        $eof ? $self->loop->new_future->fail_later('EOF') : $self->loop->new_future->done_later;
      });
    });
  }

  $f;
}

1;
