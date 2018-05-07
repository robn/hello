package Hello::Tester::Role::Banner;

use 5.020;
use warnings;
use strict;

use Moo::Role;

use Types::Standard qw(Str);

use IO::Async::Stream;

has banner => ( is => 'ro', isa => Str, required => 1 );

requires qw(loop);

sub wrap_banner {
  my ($self, $f) = @_;
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

1;
