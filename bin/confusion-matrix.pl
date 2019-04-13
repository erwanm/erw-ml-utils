#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;

my %res;
my %keys2;
my $total=0;

sub usage {
    my $fh = shift;
    $fh = *STDOUT if (!defined $fh);
    print $fh "Usage: confusion-matrix.pl [-d]\n";
    print $fh "\n";
    print $fh "  Reads a 3 columns input <key1> <key2> <val> from STDIN and writes a\n";
    print $fh "  two ways table to STDOUT.\n";
    print $fh "   -d: also prints details (percentage, precision/recall/f-measures by line)\n";
    print $fh "\n";
}

# PARSING OPTIONS                                                                                                                                                       
my %opt;
getopts('hd', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "0 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 0);
my $details=defined($opt{d});

my %positiveVal2;
while (<STDIN>) {
    chomp;
    my @cols = split;
    if (scalar(@cols) == 3) {
	$res{$cols[0]}->{$cols[1]} = $cols[2];
	$keys2{$cols[1]} = 1;
	$total += $cols[2];
	$positiveVal2{$cols[1]} +=$cols[2];
    } else {
	print STDERR "3 columns!\n";
	exit 1;
    }
}
print "\t\t".join("\t\t", sort keys %keys2);
print "\t\tPrec.%\t\tRecall%\t\tF1%" if ($details);
print "\n";
foreach my $val1 (sort keys %res) {
    print "$val1";
    my $n;
    my $actualVal1 = 0;
    foreach my $val2 (keys %keys2) {
	$n = $res{$val1}->{$val2};
	$n = 0 if (!defined($n));
	$actualVal1+=$n;
#	if ($details) {
#	    printf("\t\t$n [%.2f%%]", $n/$total*100);
#	} else {
	    printf("\t\t$n");
#	}
    }
    if ($details) {
	my $tp = $res{$val1}->{$val1};
	$tp=0 if (!defined($tp));
	my $prec = (defined($positiveVal2{$val1}))?($tp / $positiveVal2{$val1}):"NaN";
	my $recall = ($actualVal1>0)?($tp / $actualVal1):"NaN";
	my $f1 = (($prec ne "NaN")&&($recall ne "NaN") && ($prec+$recall>0) )?( 2 * $prec * $recall / ($prec + $recall)):"NaN";
	my $str = ($prec ne "NaN")?sprintf("\t\t%.2f", $prec*100):"\t\tNaN";
	$str .= ($recall ne "NaN")?sprintf("\t\t%.2f", $recall*100):"\t\tNaN";
	$str .= ($f1 ne "NaN")?sprintf("\t\t%.2f", $f1*100):"\t\tNaN";
	print "$str";
    }
    print "\n";
}
