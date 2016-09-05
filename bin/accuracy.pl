#!/usr/bin/perl

# EM 28/02/13, updated Sept 2016


use strict;
use warnings;
use Getopt::Std;

my $progName = "accuracy.pl";
my $c1 = 0;
my @labelsGold = ("0","1");

my $specialUnanswered = "## UNANSWERED ##";
my $nbDigits=undef;

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: $progName <gold file> <predicted file>\n";
	print $fh "\n";
	print $fh "   Computes the accuracy of a set of binary predictions given in\n";
	print $fh "   <predicted file> against the corresponding set of gold values\n";
	print $fh "   given in <gold file>. Both files follow the format:\n";
	print $fh "   <instance id> <value>, with one instance by line (the instances\n";
	print $fh "   can be in any order).\n";
	print $fh "   For each instance, <gold file> contains 0 (negative) or 1 \n";
	print $fh "   (positive); <predicted file> contains a value v in [0,1],\n";
	print $fh "   where v>0.5 means positive and v<=0.5 means negative (see\n";
	print $fh "   also  option -c).\n";

	print $fh "\n";
	print $fh "Options:\n";
	print $fh "  -h: help message\n";
	print $fh "  -c: compute C\@1 instead of accuracy: instances scored exactly\n";
	print $fh "      0.5 are considered 'unanswered'.\n";
        print $fh "  -p <precision>: number of decimal digits in the result.\n";
 	print $fh "  -l <pos:neg>: specify labels in gold file instead of 0 and 1.\n"; 
	print $fh "\n";
}

# PARSING OPTIONS
my %opt;
getopts('hl:cp:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "2 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
my $goldFile = $ARGV[0];
my $predFile =  $ARGV[1];

$c1 = defined($opt{c});
$nbDigits = $opt{p} if (defined($opt{p}));

@labelsGold = split(":", $opt{l}) if (defined($opt{l}));

my %pred;
my %gold;

open( GOLD, "<", $goldFile ) or die "Cannot read $goldFile.";
while (<GOLD>) {
    chomp;
    my @cols = split;
    $gold{$cols[0]} = $cols[1];
}
close(GOLD);
open(PRED, "<" , $predFile) or die "Cannot read $predFile.";
while (<PRED>) {
    chomp;
    my @cols = split;
    if ($cols[1] > 0.5) {
	$pred{$cols[0]} = $labelsGold[1];
    } else {
	if ($c1 && ($cols[1] == 0.5)) {
	    $pred{$cols[0]} = $specialUnanswered;
	} else {
	    $pred{$cols[0]} = $labelsGold[0];
	}
    }
#    print STDERR "DEBUG: pred{$cols[0]} = $pred{$cols[0]}\n";
#    print "A\t$cols[0]\n";
}
close(PRED);

die "Error: gold file '$goldFile' contains ".scalar(keys %gold)." instances whereas pred file '$predFile' contains  ".scalar(keys %pred)." instances." if (scalar(keys %gold) != scalar(keys %pred));


my ($tp,$tn,$total, $unans) =(0,0,0,0);
foreach my $id (keys %gold) {
    die "Error: no id '$id' found in pred file '$predFile'." if (!defined($pred{$id}));
#    print "B\t$id\n";
    $total++;
    if ($pred{$id} eq $specialUnanswered) {
	$unans++;
    } else {
	if ($gold{$id} eq $pred{$id}) {
	    if ($gold{$id} eq $labelsGold[1]) {
		$tp++;
	    } elsif ($gold{$id} eq $labelsGold[0]) {
		$tn++;
	    } else  {
		die "BUG, gold value is '$gold{$id}'; expecting '$labelsGold[0]' or '$labelsGold[1]'";
	    }
	}
    }
 #   print STDERR "DEBUG: id=$id,total=$total,tn=$tn,tp=$tp,unans=$unans,pred=$pred{$id},gold=$gold{$id}\n";

}
if ($c1) {
    my $correct = $tp + $tn;
    my $c1 = ($correct + ($unans * $correct/$total)) / $total ;
    if (defined($nbDigits)) {
	printf("%.${nbDigits}f\t$tp\t$tn\t$unans\n", $c1);
    } else {
	print "$c1\t$tp\t$tn\t$unans\n";
    }
} else {
    my $accu=($tp+$tn)/$total;
    if (defined($nbDigits)) {
	printf("%.${nbDigits}f\t$tp\t$tn\n", $accu);
    } else {
	print "$accu\t$tp\t$tn\n";
    }
}

