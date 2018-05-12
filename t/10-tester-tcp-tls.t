#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;

use IO::Async::Loop;
use IO::Async::SSL;
use IO::Socket::SSL::Utils;
use Net::EmptyPort qw(empty_port);

use Hello::Tester::tcp_tls;

my $SSL_CERT = IO::Socket::SSL::Utils::PEM_string2cert(<<EOF);
-----BEGIN CERTIFICATE-----
MIICmjCCAYICCQD8O8O3veqelzANBgkqhkiG9w0BAQsFADAPMQ0wCwYDVQQDDAR0
ZXN0MB4XDTE4MDUwODIyNDczOVoXDTE5MDUwODIyNDczOVowDzENMAsGA1UEAwwE
dGVzdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOpEmi9W7oS36+WE
wg19+OQEco+EHamrQMqU0m9IDwlHFXOY1nx6hF+h8iHZjgtI8DfLPcpwD7OCI1B7
iiRloVScaQIM0y5wj/oO/FmFiv/sTCWN6UBamm66jvi0F/MpNXyFhNmPgovIQjru
qjv1WUgDOLlBgaAh2TGRRntNggbznpweybJCG2p84Td32PeZuKQoDankpXPeuPO5
WNU+j3EMJf4YEdggz5ztrEzxQfEZKRoP3QNwpq3Y2pFsrx8TznYLWLXvhuS4H8Os
0SJd2K0oWnnDDsLEruXNizZGiJMWU3g3Dvew7/QfA73NCekSGIdRsqmFe7od8e/W
AfXXdVcCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEABfA6qwET5nlJ+CMBP3MP2bG6
8yUX6bAeSvNuRgdHagcxrc/2kowUILOTTMGZ02mugmoI6MMHAtIMrk7WZbhxYfCw
tg9Ny85HcumJD6QnxID9BzeXBmd/4PFXJYD/o8k0nBs7zQNJLIWM9sKGvaS65LXa
FThQIqQVqj3UNEGJYgvacbmoxvNgUKwDgcrEM1qNbRniachOaDd5XTvsQAYjDM1Y
UA4dgWGicKJZ+oyb8oj3w0GOwZK/JjLr6mdJggrOQ/gInwk5DD34PRg38TxTFrda
XzvFJI+zHGhdMV7lXbeJMg1p2NbqcHTc+v+OG85KuMwZEhLFZkbl1mYfzYUXhg==
-----END CERTIFICATE-----
EOF
my $SSL_KEY = IO::Socket::SSL::Utils::PEM_string2key(<<EOF);
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDqRJovVu6Et+vl
hMINffjkBHKPhB2pq0DKlNJvSA8JRxVzmNZ8eoRfofIh2Y4LSPA3yz3KcA+zgiNQ
e4okZaFUnGkCDNMucI/6DvxZhYr/7EwljelAWppuuo74tBfzKTV8hYTZj4KLyEI6
7qo79VlIAzi5QYGgIdkxkUZ7TYIG856cHsmyQhtqfOE3d9j3mbikKA2p5KVz3rjz
uVjVPo9xDCX+GBHYIM+c7axM8UHxGSkaD90DcKat2NqRbK8fE852C1i174bkuB/D
rNEiXditKFp5ww7CxK7lzYs2RoiTFlN4Nw73sO/0HwO9zQnpEhiHUbKphXu6HfHv
1gH113VXAgMBAAECggEBAKnKHOHQpMDGOI+5/5cdxSUl4A4KWCFfwG7THA2RcWxs
+6wzisjfV0+kpURJVHzzWT9m65rsS0T0PjoXv9CPZDVZw3W769dNt9wpvlX3xv2j
urDBQNvmjuVQC01P4cfYBy7/6oBwVdKPywjBb9pTAWmDBDqospVn0u3s9+NoEqSL
zCmcSTYZ+i6nc5p4rXpA/wiOdoDtB1NYG52jmVeXGpw5Uqe/6CqVTHqrVPr4ywbV
8mSReXT5YeBt2BNrvqOPi2xREe27W0VA1yikK7t4iLta8GQezHctd2IdUn2N3Xrz
Y7OdEg4aa4NC8evDcfNVpnDiT9s/SZrL5QG8WzK5N9ECgYEA/VUzGq/qEpesUMox
ELPItk2K2ZH0HLdxSOHjxJjV9z+DK49KHGOfqMxxqREDNr4GBsFBNr9gJQVo9NJ5
2FVfKdPWHKn2I3VNPL1CYXbDbz+Fjb/h6pm7lVXBc1Z03iMlPKqz4/h3jzvS5v2O
+yDkNcucNOvaGYhNcDTK6Pe328kCgYEA7LwEjVleWBnV1BJtl81XCSy7+6xYKeug
jYZudGz0oCx4HspkY1XZ9f2D9BDwNzwEJl7CDyv5UN32bJjqTTTOeFe+JRlWvG4g
+ijzUaWZBS1ZyG+HcdBHuq5nKco59aDefzL2OKR4wYup5qK7gd9UZT6eMuMl23s9
UXVF76SxGB8CgYAhasy793qUC0fivFkuj9ipG592RceCxjv+VjXaaCLJY6pk45ju
F8Im3RkdKS5YWUaoO3Pjyejf2U/YA6+o9tH/zX7P9yeN09plab3I54auNR3j7eza
Kn9RGqfTFBOEffRahVYHe24iCc0vRUFIJTWVVw9696WkepNkesJNaufo6QKBgQCH
3ANUx2QQdYs0sPq6MrrvZf/gGHFkZXh3oB3FrT3aqoqpSQfBxmRW+w3+RLZHTKcp
ChqesGLdmPSyMDPO6S5Q/DIAgoE3lJBSYKv7QGkIApXTJMZ7d8eiiDJmVkta/t6R
60JJEYLHuIph9SRdDTkW/Y+2rotsYVa4Z/Ah7sc/iwKBgEGfuu2+haz+aEJQEfFG
U1+ciW0yTgBKRIUy29wFKwD8VCzUyYe0lt1RtkJsQrK3drC/FhMEzA++zOcUp3Qe
9+OwZ7oxbJyqlRK4agCZWk6+pl6C9k49yYPv9Z+DKxwavWwhrNKb0JoHqioT2yKI
Zw66nCoYhEUfuRiL/3RP4R+S
-----END PRIVATE KEY-----
EOF

my $loop = IO::Async::Loop->new;

my $port = empty_port;

my $t = Hello::Tester::tcp_tls->new(
  loop   => $loop,
  name   => "tcp_tls",
  ip     => "127.0.0.1",
  port   => $port,
  verify => 0,
);

ok($t->test->else_done(1)->get, "connection failed when listener doesn't exist");

$loop->SSL_listen(
  addr => {
    family   => 'inet',
    socktype => 'stream',
    ip       => '127.0.0.1',
    port     => $port,
  },
  SSL_cert => $SSL_CERT,
  SSL_key  => $SSL_KEY,
  on_stream => sub {},
  on_listen_error => sub {},
  on_ssl_error => sub {},
);

ok($t->test->then_done(1)->else_done(0)->get, 'connection succeeded when listener exists');

my $t2 = Hello::Tester::tcp_tls->new(
  loop   => $loop,
  name   => "tcp_tls verify",
  ip     => "127.0.0.1",
  port   => $port,
  verify => 1,
);

ok($t2->test->then_done(0)->else_done(1)->get, 'connection failed when cert verification failed');

done_testing;
