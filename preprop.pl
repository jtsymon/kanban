#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

my $usage = "Usage: ./preprop.pl [-I include_dir]* [-E file_extension] source\n";
my @include = ( "." );
my $extension;
my $source;
while (@ARGV) {
    for (shift @ARGV) {
        /^-I$/ and do {
            unshift @include, shift @ARGV;
            last;
        };
        /^-E$/ and do {
            die $usage if defined $extension;
            $extension = shift @ARGV;
            last;
        };
        die $usage if defined $source;
        $source = $_;
    }
}
die $usage unless defined $source;
$extension = "" unless defined $extension;

open SOURCE, $source or die $!;

while (<SOURCE>) {
    my ($file) = /^\@import +([^\s]+)$/;
    if (defined $file) {
        my $success = 0;
        for my $dir (@include) {
            my $path = "$dir/$file.$extension";
            if (-f $path) {
                open IMPORT, $path or die $!;
                print while (<IMPORT>);
                $success = 1;
                close IMPORT;
                last;
            }
        }
        die "Failed to find '$file'\n" unless $success;
    } else {
        print;
    }
}
close SOURCE;

