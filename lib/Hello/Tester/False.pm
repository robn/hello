package Hello::Tester::False;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

sub description { "always fail" }

sub test {
  return Future->fail("failures gotta fail");
}

1;
