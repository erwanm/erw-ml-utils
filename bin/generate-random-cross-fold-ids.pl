#!/usr/bin/perl


# EM Feb 14 - better than previous "bad" version
# could easily be optimized but I don't think it matters here.
#

use strict;
use warnings;
use Getopt::Std;

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n";
	print $fh "Usage: generate-random-cross-fold-ids.pl [options] <nb folds> <max id> <name prefix>\n";
	print $fh "  Writes <nb folds> * 2 files named <prefix>.<fold no>.<test|train>.indexes,\n";
	print $fh "  where the indexes 1 to <max id> are randomly assigned to a test set file\n";
	print $fh "  and every index which is not in the test file is in the train file.\n";
	print $fh "  Remark: <name prefix> can include a path.\n";
	print $fh "\n";
	print $fh "Options:\n";
	print $fh "  -h print this message\n";
	print $fh "  -s do not write train set files.\n";
	print $fh "\n";
}

# PARSING OPTIONS
my %opt;
getopts('hs', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "3 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 3);
my $noTrainSetFiles=$opt{s};

sub writeList {
    my ($list , $filename) = @_;
    open(FH, ">", $filename) or die "Can not write to $filename";
    foreach my $e (sort { $a <=> $b } @$list) {
	print FH "$e\n";
    }
    close(FH);
}

sub pickOne {
    my ($list) = @_;
    die "Error: empty list" if (scalar(@$list)==0);
    my $randomIndex = int(rand(scalar(@$list)));
    my $val = $list->[$randomIndex];
    my @newList = @$list[0..$randomIndex-1,$randomIndex+1..scalar(@$list)-1];
#    print STDERR "DEBUG old=".scalar(@$list)." ; new=".scalar(@newList)."\n";
    return ($val, \@newList);
}

sub onlyNotMember {
    my ($inputList, $filterList) = @_;
    my @res;
    my %filterH = map { $_ => 1 } @$filterList; # the easy way
    foreach my $e (sort { $a <=> $b } @$inputList) {
	push(@res, $e) if (!$filterH{$e});
    }
    return \@res;
}



my $nbFolds=$ARGV[0];
my $maxId=$ARGV[1];
my $name=$ARGV[2];

my $nbDigits = length($nbFolds);
my @allSeq = (1..$maxId);
my $nbByFold = $maxId / $nbFolds ;
my $remaining;
@$remaining = @allSeq;
my $numFold=1;
my @foldsTest;
while (scalar(@$remaining)>0) {
    my $val;
    ($val, $remaining)  = pickOne($remaining);
    push(@{$foldsTest[$numFold]}, $val);
    $numFold++;
    $numFold = 1 if ($numFold>$nbFolds);
}
for (my $num = 1; $num<=$nbFolds ; $num++) {
    my $numS=sprintf("%0${nbDigits}d", $num);
    writeList($foldsTest[$num], "$name.$numS.test.indexes");
    if (!$noTrainSetFiles) {
	writeList(onlyNotMember(\@allSeq, $foldsTest[$num]), "$name.$numS.train.indexes");
    }
}
