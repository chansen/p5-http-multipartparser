#!/usr/bin/perl
use strict;
use warnings;

use HTTP::MultipartParser qw[];
use Hash::MultiValue       qw[];
use IO::File               qw[SEEK_SET];
use File::Temp             qw[];

my $params  = Hash::MultiValue->new;
my $uploads = Hash::MultiValue->new;

my $part;
my $parser = HTTP::MultipartParser->new(
    boundary  => '----------0xKhTmLbOuNdArY',
    on_header => sub {
        my ($headers) = @_;

        my ($name, $filename);
        foreach (@$headers) {
            if (/\A Content-Disposition: /xi) {
                ($name)     = / name="?([^\";]+)"?/;
                ($filename) = / filename="?([^\"]*)"?/;
                last;
            }
        }

        $part = {
            name    => $name,
            headers => $headers,
        };

        if (defined $filename) {
            $part->{filename} = $filename;

            if (length $filename) {
                my $fh = File::Temp->new(UNLINK => 1);
                $part->{fh}       = $fh;
                $part->{tempname} = $fh->filename;
            }
        }
    },
    on_body => sub {
        my ($chunk, $final) = @_;

        my $fh = $part->{fh};

        if ($fh) {
            print $fh $chunk
              or die qq/Could not write to file handle: '$!'/;
            if ($final) {
                seek($fh, 0, SEEK_SET)
                  or die qq/Could not rewind file handle: '$!'/;
                $part->{size} = -s $fh;
                $uploads->add($part->{name}, $part);
            }
        }
        else {
            $part->{data} .= $chunk;
            if ($final) {
                $params->add($part->{name}, $part->{data});
            }
        }
    }
);

open my $fh, '<:raw', 't/data/001-content.dat'
  or die;

while () {
    my $n = read($fh, my $buffer, 1024);
    unless ($n) {
        die qq/Could not read from fh: '$!'/
          unless defined $n;
        last;
    }
    $parser->parse($buffer);
}

$parser->finish;

