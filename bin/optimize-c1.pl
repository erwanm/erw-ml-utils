#!/usr/bin/perl

# EM 12/02/13


use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;

my $col=1;
my $progName="optimize-c1.pl";



sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: $progName [options] <predicted scores file> <truth file>\n";
	print $fh "\n";
	print $fh "  Predicted scores are in [0,1], truth scores are only 0 or 1.\n";
	print $fh "  One score by line, same number of lines in both files (and.\n";
	print $fh "  same order of cases).\n";
	print $fh "  Tries to find the optimal two bounds for the 0.5 scores (unknown)\n";
	print $fh "  in order to maximize the c\@1 performance score:\n";
	print $fh "    c\@1 = (1/n)*(nc+(nu*nc/n))\n";
	print $fh "  where n=total number of problems, nc=number of correct answers,\n";
	print $fh "  nu= number of unanswered problems (0.5 scores). scores<0.5 and\n";
	print $fh "  scores>0.5 are considered labelled negative and positive, respectively.\n";
	print $fh "  Output theresholds printed to STDOUT as <min> <max> <perf>.\n";
	print $fh "\n";
	print $fh "\n";
	print $fh "   Options:\n";
	print $fh "   -c <col> read score from column <col> (in both files).\n";
	print $fh "\n";
}


sub readValues {
    my $file = shift;
    open(FH, "<", $file) or die "$progName: cannot open file '$file'";
    my @res;
    while (<FH>) {
	chomp;
	my @cols=split;
	my $val = $cols[$col];
	die "$progName: value undefined in column ".($col+1)." in file '$file'" if (!defined($val));
	push(@res, $val);
    }
    close(FH);
    return \@res;
}


sub perf {
    my ($c, $u, $n) = @_;
    return ($c + $u * ( $c / $n )) / $n ;
}

sub zeroIfUndef {
    my $v = shift;
    if (defined($v)) {
	return $v;
    } else {
	return 0;
    }
}


# PARSING OPTIONS
my %opt;
getopts('c:h', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "2 argument expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
$col = $opt{c} if (defined($opt{c}));
my $predictFile = $ARGV[0];
my $goldFile = $ARGV[1];
$col--;

my $goldValues = readValues($goldFile);
my $predictValues = readValues($predictFile);
die "$progName: different number of values in gold file '$goldFile' and predict file '$predictFile'" if (scalar(@$goldValues) != scalar(@$predictValues));

my %byPredictScore;
my %sums;

for (my $i=0; $i<scalar(@$goldValues); $i++) {
    if ($predictValues->[$i]==0.5) {
	$byPredictScore{0}->{$predictValues->[$i]}->{$goldValues->[$i]}++;
	$sums{0}->{total}++;
    } elsif ($predictValues->[$i]<0.5) {
	$byPredictScore{-1}->{$predictValues->[$i]}->{$goldValues->[$i]}++;
	$sums{-1}->{correct}++ if ($goldValues->[$i] == 0);
	$sums{-1}->{total}++;
    } elsif ($predictValues->[$i]>0.5) {
	$byPredictScore{1}->{$predictValues->[$i]}->{$goldValues->[$i]}++;
	$sums{1}->{correct}++ if ($goldValues->[$i] == 1);
	$sums{1}->{total}++;
    }
}

#print Dumper(\%byPredictScore);

my %sorted;
@{$sorted{1}} =  sort { $a <=> $b } keys %{$byPredictScore{1}}; # sorted from 0.5 to 1
@{$sorted{-1}} =  sort { $b <=> $a } keys %{$byPredictScore{-1}}; # sorted from 0.5 to 0

my $u1 = zeroIfUndef($sums{0}->{total});
my $c1 = zeroIfUndef($sums{1}->{correct}) + zeroIfUndef($sums{-1}->{correct});
my $total = zeroIfUndef($sums{1}->{total}) + zeroIfUndef($sums{0}->{total}) + zeroIfUndef($sums{-1}->{total});
my %perf;
$perf{0.5}->{0.5} = perf($c1, $u1, $total);
my @best = (0.5, 0.5);
#print STDERR "DEBUG $progName best=[".join(";", @best)."]; perf=".$perf{$best[0]}->{$best[1]}."\n";
for (my $up=0; $up<scalar(@{$sorted{1}}); $up++) {
    my $highLimit = $sorted{1}->[$up];
 #   print STDERR "DEBUG highLimit=$highLimit\n";
    $u1 +=  zeroIfUndef($byPredictScore{1}->{$highLimit}->{0}) + zeroIfUndef($byPredictScore{1}->{$highLimit}->{1});
    $c1 -= zeroIfUndef($byPredictScore{1}->{$highLimit}->{1});
    my $u2 = $u1;
    my $c2 = $c1;
    for (my $down=0; $down<scalar(@{$sorted{-1}}); $down++) {
    # take the mean value between the current score (which should be included) and the next (which should be excluded)
	my $lowLimit = $sorted{-1}->[$down];
#	print STDERR "DEBUG lowLimit=$lowLimit\n";
	$u2 +=  zeroIfUndef($byPredictScore{-1}->{$lowLimit}->{0}) + zeroIfUndef($byPredictScore{-1}->{$lowLimit}->{1});
	$c2 -= zeroIfUndef($byPredictScore{-1}->{$lowLimit}->{0});
	# take the mean value between the current score (which should be included) and the next (which should be excluded)
	my $hl =  ($up+1<scalar(@{$sorted{1}})) ? ($highLimit+ $sorted{1}->[$up+1]) / 2 : ($highLimit+ 1) / 2 ;
	my $ll = ($down+1 < scalar(@{$sorted{-1}})) ? ($lowLimit + $sorted{-1}->[1]) / 2 : ($lowLimit + 0) / 2 ;
	$perf{$ll}->{$hl} = perf($c2, $u2, $total);
	if ($perf{$ll}->{$hl} > $perf{$best[0]}->{$best[1]}) {
	    @best = ( $ll, $hl ) ;
#	    print STDERR "DEBUG $progName best=[".join(";", @best)."]; perf=".$perf{$best[0]}->{$best[1]}."\n";
	}
    }
}

# DEBUG
#foreach my $low (sort { $b <=> $a } keys %perf) {
#    foreach my $high (sort { $a <=> $b } keys %{$perf{$low}}) {
#	print STDERR "DEBUG $progName perf for [$low;$high] = ".$perf{$low}->{$high}."\n";
#    }
#}
print "$best[0]\t$best[1]\t".$perf{$best[0]}->{$best[1]}."\n";
