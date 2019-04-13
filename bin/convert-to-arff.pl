#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;

my $separator = "\t";
my $nameRelation = "my-data";
sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: convert-to-arff.pl [-b] [-n <nominal columns names[;<possible values , separated>] ':' separated>]\n";
	print $fh "   input read from stdin, output written to stdout.\n";
	print $fh " input file must have a header line with columns titles\n";
	print $fh " -b = attributes are binary (0,1 values) instead of numeric by default\n";
}

# PARSING OPTIONS
my %opt;
getopts('hbn:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "0 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 0);
my $nominalNames=$opt{n};
my $binary = $opt{b};

my %valuesAsInput;
my %possibleValues;
if (defined($nominalNames)) {
    foreach my $nameValues (split(":", $nominalNames)) {
	if ($nameValues =~ m/;/) {
	    my ($name, $values) = ($nameValues =~ m/(\S+);(\S+)/);
	    $valuesAsInput{$name}=1;
	    foreach my $val (split(",",$values)) {
		$possibleValues{$name}->{$val} = 1;
	    }
	} else {
#    print STDERR "DEBUG $name?\n";
	    $possibleValues{$nameValues} = {};
	}
    }
}
my @data = <STDIN>;

my $header = shift(@data);
chomp($header);
my @header = split(/\t+/, $header);
my %colsNominal;
for (my $i=0; $i<scalar(@header); $i++) {
#    print STDERR "debug: col $i='$header[$i]'\n";
    $colsNominal{$header[$i]} = $i if (defined($possibleValues{$header[$i]}));
}
foreach my $name (keys %possibleValues) {
    die "Error: no column title '$name' in header." if (!defined($colsNominal{$name}));
}


foreach (@data) {
    chomp;
    my @columns = split(/\t/, $_);
    foreach my $name (keys %possibleValues) {
	if (defined($valuesAsInput{$name})) {
	    die "Invalid value for $name: ".$columns[$colsNominal{$name}] if (($columns[$colsNominal{$name}] ne "?") && (!defined($possibleValues{$name}->{$columns[$colsNominal{$name}]})));
	} else {
#	print STDERR "DEBUG $name...".$columns[$colsNominal{$name}]."\n";
	    $possibleValues{$name}->{$columns[$colsNominal{$name}]} = 1;
	}
    }
}


# arff header
print "\@RELATION $nameRelation\n";

foreach my $attr (@header) {
    if (defined($possibleValues{$attr})) {
	print "\@ATTRIBUTE '$attr' {".join(",", (sort keys %{$possibleValues{$attr}}))."}\n";
    } else {
	if ($binary) {
	    print "\@ATTRIBUTE '$attr' {0,1}\n";
	} else {
	    print "\@ATTRIBUTE '$attr' NUMERIC\n";
	}
    }
}
print "\@DATA\n";
foreach (@data) {
    chomp;
    my @l = split;
#    print STDERR "DEBUG '$l'\n";
#    $l =~ s/$separator/,/;
    print join(",",@l)."\n";
}
