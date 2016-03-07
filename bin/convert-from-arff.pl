#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;

my $separator = "\t";
sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: convert-to-arff.pl [-t]\n";
	print $fh "   input read from stdin, output written to stdout.\n";
	print $fh " -t: header line (columns 'T'itles)\n";
}

# PARSING OPTIONS
my %opt;
getopts('ht', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "0 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 0);
my $printHeader=$opt{t}?1:0;

my $lineNo=1;
my $inHeader=1;
my $firstCol=1;
while (<STDIN>) {
    chomp;
    if (m/\S/) { # not empty line
	if ($inHeader) {
	    if (m/^\s*\@ATTRIBUTE/i) {
		if ($printHeader) {
		    my ($name) = (m/^\s*\@ATTRIBUTE\s+(\S+)\s+/i);
		    if ($name =~ m/^\'/) {
			($name) = ($name =~ m/^\'(.+)\'$/);
		    }
		    print $separator unless ($firstCol);
		    print "$name";
		    $firstCol=0;
		}
	    } elsif (m/^\s*\@DATA/i) {
		$inHeader = 0;
		print "\n" if ($printHeader);
	    } # otherwise ignore
	} else {
	    my @values = split(",", $_);
	    my @noQuotes = map { (m/^".*"$/)?substr($_, 1, -1):$_ } @values;
	    print join($separator, @noQuotes)."\n";
	}
	$lineNo++;
    }
}

