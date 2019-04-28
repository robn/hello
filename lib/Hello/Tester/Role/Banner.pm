package Hello::Tester::Role::Banner;

use 5.020;
use warnings;
use strict;

use Moo::Role;

use Types::Standard qw(RegexpRef);

use IO::Async::Stream;

has banner => (
  is       => 'ro',
  isa      => RegexpRef,
  required => 1,
  coerce   => sub { ref $_[0] ? $_[0] : qr/$_[0]/ },
);

requires qw(loop);

sub wrap_banner {
  my ($self, $f) = @_;
  my $re = $self->banner;
  $f = $f->then(sub {
    my $h = IO::Async::Stream->new(read_handle => shift, on_read => sub {});
    $self->loop->add($h);
    $h->read_until(qr/$re/)->then(sub {
      my ($read, $eof) = @_;
      $h->close_now;
      $eof ? $self->loop->new_future->fail_later('EOF') : $self->loop->new_future->done_later;
    });
  });
}

1;
