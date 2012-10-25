use strict;
use inc::Module::Install;

name           'Parse-HTTP-Multipart';
perl_version   '5.008001';
all_from       'lib/Parse/HTTP/Multipart.pm';
repository     'http://github.com/chansen/p5-parse-http-multipart';
readme_from    'lib/Parse/HTTP/Multipart.pod';

requires       'Carp'         => '0';
requires       'Scalar::Util' => '0';
test_requires  'Test::More'   => '0.88';
test_requires  'Test::Deep'   => '0';

tests 't/*.t';

WriteAll;
