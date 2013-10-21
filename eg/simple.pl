#!/usr/bin/perl
use strict;
use warnings;

use HTTP::MultiPartParser qw[];
use HTTP::Headers::Util   qw[split_header_words];
use HTTP::Message         qw[];
use HTTP::Headers         qw[];

# headers_as = lines | pairs | chunk

use Data::Dump qw[dd];
my @parts;
my %part;
my $on_header = sub {
    my ($header) = @_;

    dd $header;
    dd [split /\x0D\x0A/, $header];
    
    #my $header = HTTP::Message->parse(join "\r\n", @$lines);
    #print $header->as_string;
};

my $on_body = sub { };

my $parser = HTTP::MultiPartParser->new(
    header_as => 'unparsed',
    boundary  => '---------------------------168072824752491622650073',
    on_error  => \&Carp::confess,
    on_header => $on_header,
    on_body   => $on_body,
);

while (<DATA>) {
    s/\n\z/\r\n/;
    $parser->parse($_);
}

$parser->finish;

__DATA__
-----------------------------168072824752491622650073
Content-Disposition:       form-data; name="text1"
Ddd

Ratione accusamus aspernatur aliquam
-----------------------------168072824752491622650073
Content-Disposition: form-data; name="text2"


-----------------------------168072824752491622650073
Content-Disposition: form-data; name="select"

A
-----------------------------168072824752491622650073
Content-Disposition: form-data; name="select"

B
-----------------------------168072824752491622650073
Content-Disposition: form-data; name="textarea"

Voluptatem cumque voluptate sit recusandae at. Et quas facere rerum unde esse. Sit est et voluptatem. Vel temporibus velit neque odio non.

Molestias rerum ut sapiente facere repellendus illo. Eum nulla quis aut. Quidem voluptas vitae ipsam officia voluptatibus eveniet. Aspernatur cupiditate ratione aliquam quidem corrupti. Eos sunt rerum non optio culpa.
-----------------------------168072824752491622650073
Content-Disposition: form-data; name="upload"; filename="hello.pl"
Content-Type: text/plain

#!/usr/bin/perl

use strict;
use warnings;

print "Hello World :)\n";


-----------------------------168072824752491622650073
Content-Disposition: form-data; name="upload"; filename="hello.pl"
Content-Type: text/plain

#!/usr/bin/perl

use strict;
use warnings;

print "Hello World :)\n";


-----------------------------168072824752491622650073
Content-Disposition: form-data; name="upload1"; filename=""
Content-Type: application/octet-stream


-----------------------------168072824752491622650073
Content-Disposition: form-data; name="upload2"; filename="hello.pl"
Content-Type: text/plain

#!/usr/bin/perl

use strict;
use warnings;

print "Hello World :)\n";


-----------------------------168072824752491622650073--
