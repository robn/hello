requires "Carp" => "0";
requires "Defined::KV" => "0";
requires "Future" => "0";
requires "Future::Utils" => "0";
requires "Getopt::Long::Descriptive" => "0";
requires "IO::Async::Loop" => "0";
requires "IO::Async::SSL" => "0";
requires "IO::Async::Stream" => "0";
requires "Log::Dispatchouli" => "2.002";
requires "Log::Dispatchouli::Global" => "0";
requires "MIME::Base64" => "0";
requires "Module::Runtime" => "0";
requires "Moo" => "0";
requires "Moo::Role" => "0";
requires "Net::Async::HTTP" => "0";
requires "Net::Async::HTTP::Server::PSGI" => "0";
requires "Net::Async::Ping" => "0";
requires "Net::Prometheus" => "0";
requires "Plack::Middleware::AccessLog" => "0";
requires "TOML" => "0";
requires "Time::HiRes" => "0";
requires "Type::Params" => "0";
requires "Type::Utils" => "0";
requires "Types::Standard" => "0";
requires "experimental" => "0";
requires "parent" => "0";
requires "perl" => "5.020";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "File::Temp" => "0";
  requires "IO::Socket::SSL::Utils" => "0";
  requires "Net::EmptyPort" => "0";
  requires "Test::More" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};
