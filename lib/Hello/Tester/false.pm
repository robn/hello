package Hello::Tester::false;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

sub test {
  return Future->fail("failures gotta fail");
}

1;
