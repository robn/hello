package Hello::Tester::True;

use 5.020;
use warnings;
use strict;

use Moo;
with 'Hello::Tester';

sub description { "always succeed" }

sub test {
  return Future->done;
}

1;
