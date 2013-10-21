#!perl

use strict;
use warnings;

use Test::More tests => 1;

require_ok('HTTP::MultipartParser');
diag("HTTP::MultipartParser $HTTP::MultipartParser::VERSION, Perl $], $^X");

