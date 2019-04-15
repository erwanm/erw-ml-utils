#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;

my %res;
my %keys2;
my $total=0;
my $allKeys=0;
my $onlyAccu=0;

sub usage {
    my $fh = shift;
    $fh = *STDOUT if (!defined $fh);
    print $fh "Usage: confusion-matrix.pl [-d]\n";
    print $fh "\n";
    print $fh "  Reads a 3 columns input <key1> <key2> <val> from STDIN and writes a\n";
    print $fh "  two ways table to STDOUT.\n";
    print $fh "   -d: also prints details (percentage, precision/recall/f-measures by line)\n";
    print $fh "   -p: print all the possible keys as line and column (square matrix).\n";
    print $fh "   -a: only output accuracy\n";
    print $fh "\n";
}

# PARSING OPTIONS                                                                                                                                                       
my %opt;
getopts('hadp', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "0 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 0);
my $details=defined($opt{d});
$allKeys = defined($opt{p});
$onlyAccu = defined($opt{a});

my $countCorrect = 0;

my %positiveVal2;
while (<STDIN>) {
    chomp;
    my @cols = split;
    if (scalar(@cols) == 3) {
	$res{$cols[0]}->{$cols[1]} += $cols[2]; # fix: acculumating intead of assigning in order to take into account multiple lines with same pair of keys
#	print STDERR "DEBUG1 res{$cols[0]}->{$cols[1]}: +$cols[2] = ".$res{$cols[0]}->{$cols[1]}."\n";
	$keys2{$cols[1]} = 1;
	$countCorrect += $cols[2] if ($cols[0] eq $cols[1]);
	$total += $cols[2];
	$positiveVal2{$cols[1]} +=$cols[2];
    } else {
	print STDERR "3 columns!\n";
	exit 1;
    }
}

if ($onlyAccu) {
    my $accu = sprintf("\t%.2f", $countCorrect / $total * 100);
    print "$countCorrect\t$total\t$accu\n";
} else {

    if ($allKeys) {
	foreach my $k1 (keys %res) {
	    $keys2{$k1} = 1;
	}
	foreach my $k2 (keys %keys2) {
	    foreach my $k1 (keys %res) {
		$res{$k2}->{$k1} = 0 if (!defined($res{$k2}->{$k1}));
	    }
	}
    }

    print "\t".join("\t", sort keys %keys2);
    print "\tPrec.%\tRecall%\tF1%" if ($details);
    print "\n";
    foreach my $val1 (sort keys %res) {
	print "$val1";
	my $n;
	my $actualVal1 = 0;
	foreach my $val2 (sort keys %keys2) {
	    $n = $res{$val1}->{$val2};
	    $n = 0 if (!defined($n));
	    $actualVal1+=$n;
	    #	if ($details) {
	    #	    printf("\t$n [%.2f%%]", $n/$total*100);
	    #	} else {
	    #	print STDERR "DEBUG2 res{$val1}->{$val2}= $n\n";
	    
	    printf("\t$n");
	    #	}
	}
	if ($details) {
	    my $tp = $res{$val1}->{$val1};
	    $tp=0 if (!defined($tp));
	    my $prec = (defined($positiveVal2{$val1}))?($tp / $positiveVal2{$val1}):"NaN";
	    my $recall = ($actualVal1>0)?($tp / $actualVal1):"NaN";
	    my $f1 = (($prec ne "NaN")&&($recall ne "NaN") && ($prec+$recall>0) )?( 2 * $prec * $recall / ($prec + $recall)):"NaN";
	    my $str = ($prec ne "NaN")?sprintf("\t%.2f", $prec*100):"\tNaN";
	    $str .= ($recall ne "NaN")?sprintf("\t%.2f", $recall*100):"\tNaN";
	    $str .= ($f1 ne "NaN")?sprintf("\t%.2f", $f1*100):"\tNaN";
	    print "$str";
	}
	print "\n";
    }
}
