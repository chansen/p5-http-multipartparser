#!perl

use strict;
use warnings;

use Test::More tests => 1;

require_ok('Parse::HTTP::Multipart');
diag("Parse::HTTP::Multipart $Parse::HTTP::Multipart::VERSION, Perl $], $^X");

