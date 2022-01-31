#!/usr/bin/perl

# EM 28/02/13, updated Sept 2016


use strict;
use warnings;
use Getopt::Std;

my $progName = "auc.pl";
my $c1 = 0;
my @labelsGold = ("0","1");

my $nbDigits=undef;
my $specialUnanswered = "## UNANSWERED ##";

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: $progName <gold file> <predicted file>\n";
	print $fh "\n";
	print $fh "   Computes the AUC (area under the ROC curve) of a set of predictions\n";
	print $fh "   given in <predicted file> against the corresponding set of gold\n";
	print $fh "   values given in <gold file>. Both files follow the format:\n";
	print $fh "   <instance id> <value>, with one instance by line (the instances\n";
	print $fh "   can be in any order).\n";
	print $fh "   For each instance, <gold file> contains 0 (negative) or 1 \n";
	print $fh "   (positive); <predicted file> contains a score in [0,1] which\n";
	print $fh "   represents the likeliness of the instance to be positive.\n";
	print $fh "\n";
	print $fh "   The algorithm follows alg. 4 in 'ROC Graphs: Notes and practical\n";
	print $fh "   considerations for data mining researchers', by Tom Fawcett (2003).\n";
	print $fh "\n";
	print $fh "Options:\n";
	print $fh "  -h: help message\n";
	print $fh "  -p <precision>: number of decimal digits in the result.\n";
	print $fh "  -l <neg:pos>: specify labels in gold file instead of 0:1.\n"; 
	print $fh "\n";
}


sub trapArea {
    my ($x1, $x2, $y1, $y2) = @_;
    my $base = ($x1>=$x2) ? ($x1-$x2) : ($x2-$x1);
    my $height = ($y1+$y2)/2;
    return $base * $height;
}



# PARSING OPTIONS
my %opt;
getopts('hl:p:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "2 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
my $goldFile = $ARGV[0];
my $predFile =  $ARGV[1];

$nbDigits = $opt{p} if (defined($opt{p}));
@labelsGold = split(":", $opt{l}) if (defined($opt{l}));

my %pred;
my %gold;

open( GOLD, "<", $goldFile ) or die "Cannot read $goldFile.";
while (<GOLD>) {
    chomp;
    # if line contains tab, tab assumed as separator, otherwise any separator (probably whitespace)
    my @cols = (m/\t/) ? split('\t') : split;
#    print "DEBUG gold id = '".$cols[0]."'\n";
    $gold{$cols[0]} = $cols[1];
}
close(GOLD);
open(PRED, "<" , $predFile) or die "Cannot read $predFile.";
while (<PRED>) {
    chomp;
    # if line contains tab, tab assumed as separator, otherwise any separator (probably whitespace)
    my @cols = (m/\t/) ? split('\t') : split;
#    print "DEBUG pred id = '".$cols[0]."'\n";
    $pred{$cols[0]} = $cols[1];
}
close(PRED);

die "Error: gold file '$goldFile' contains ".scalar(keys %gold)." instances whereas pred file '$predFile' contains  ".scalar(keys %pred)." instances." if (scalar(keys %gold) != scalar(keys %pred));

my ($fp,$tp,$fpPrev, $tpPrev, $area, $totalPos, $totalNeg) =(0,0,0,0,0,0,0);
my $scorePrev = undef;


foreach my $id (sort { $pred{$b} <=> $pred{$a} } keys %pred) {
    die "Error: no id '$id' found in gold file '$goldFile'." if (!defined($gold{$id}));
#
#    print "B\t$id\n";
    if (!defined($scorePrev) || ($pred{$id} != $scorePrev)) {
	$area += trapArea($fp, $fpPrev, $tp, $tpPrev);
	$scorePrev = $pred{$id};
	$fpPrev = $fp;
	$tpPrev = $tp;
    }
    if ($gold{$id} eq $labelsGold[1]) { # positive
	$totalPos++;
	$tp++;
    } elsif ($gold{$id} eq $labelsGold[0]) {  # negative
	$totalNeg++;
	$fp++;
    } else  {
	die "BUG, gold value is '$gold{$id}'; expecting '$labelsGold[0]' or '$labelsGold[1]'";
    }
#    print STDERR "DEBUG: pred=$pred{$id}, fp=$fp, tp=$tp, totalPos=$totalPos, totalNeg=$totalNeg, area=$area\n";
}

$area += trapArea($fp, $fpPrev, $tp, $tpPrev);
#print STDERR "DEBUG: area=$area\n";
$area /= $totalPos * $totalNeg;

if (defined($nbDigits)) {
    printf("%.${nbDigits}f\n", $area);
} else {
    print "$area\n";
}
