use strict;
use warnings;
package Hello::Logger;
use parent 'Log::Dispatchouli::Global';

use Log::Dispatchouli 2.002;

sub logger_globref {
  no warnings 'once';
  \*Logger;
}

sub default_logger_class { 'Hello::Logger::_Logger' }

sub default_logger_args {
  return {
    ident     => "hello",
    facility  => 'daemon',
    to_stderr => $_[0]->default_logger_class->env_value('STDERR') ? 1 : 0,
    to_file   => $_[0]->default_logger_class->env_value('FILE') ? 1 : 0,
  }
}

{
  package Hello::Logger::_Logger;
  use parent 'Log::Dispatchouli';

  sub env_prefix { 'HELLO_LOG' }
}

1;
