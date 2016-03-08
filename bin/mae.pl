#!/usr/bin/perl
# EM Feb 2014

use strict;
use warnings;
use Getopt::Std;

my $separator = "\t";
my $indivFile;
my $details;

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: mae.pl [options] <file1[:col1]> <file2[:col2]\n";
	print $fh "  Given two tsv files file1 and file2, each containing numeric\n";
	print $fh "  columns col1 and col2 (respectively) and the same number of lines,\n";
	print $fh "  prints the Mean Absolute Error (MAE) between these two columns.\n";
	print $fh "  Uses column 1 if no column specified.\n";
	print $fh "  \n";
	print $fh "  options:\n";
	print $fh "    -h print this help message\n";
	print $fh "    -i <file> write the individual signed error (first column) and \n";
	print $fh "       absolute error (2nd column) to <file>\n";
	print $fh "    -m also compute the max, mean signed error, std dev and express\n";
	print $fh "       the mean signed|absolute error in number of std dev.\n";
	print $fh "       Remark: if -m is supplied then the comparison is directed:\n";
	print $fh "       file1 is the ref and file2 is the hypothesis.\n";
	print $fh "  \n";
}

sub readColFile {
    my ($filename, $colNo)  = @_;
    my $lineNo=1;
    my @res;
    open(FILE, "<", $filename) or die "can not open $filename";
    while (my $line = <FILE>) {
	chomp($line);
#	die "Error: empty line in $filename at line $lineNo" if (!length("line"));
	my @cols = split(/$separator/, $line);
	die "Error: only ".scalar(@cols)." columns line $lineNo in $filename" if (scalar(@cols)<=$colNo);
	push(@res, $cols[$colNo]);
	$lineNo++;
    }
    close(FILE);
    return \@res;
}


# PARSING OPTIONS
my %opt;
getopts('hi:m', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "2 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
$details=$opt{m};
$indivFile=$opt{i};
my $param1=shift;
my $param2=shift;
my ($file1, $col1) = ($param1 =~ m/:/) ? ($param1 =~ m/^(.*):(.*)$/) : ( $param1, 1);
my ($file2, $col2) = ($param2 =~ m/:/) ? ($param2 =~ m/^(.*):(.*)$/) : ( $param2, 1);
$col1--;
$col2--;

my $content1 = readColFile($file1, $col1);
my $content2 = readColFile($file2, $col2);

die "Error: number of lines differ in $file1 and $file2" if (scalar(@$content1) != scalar(@$content2));

$details = {} if (defined($details));

if (defined($indivFile)) {
    open(FILE, ">", $indivFile) or die "can not write to $indivFile";
}

my ($sumAbs, $sumSigned)=0;
for (my $i=0; $i < scalar(@$content1); $i++) {
    my $errSigned = $content2->[$i] - $content1->[$i];
    my $errAbs = abs($errSigned);
    if (defined($indivFile)) {
	print FILE "$errSigned\t$errAbs\n";
    }
    $sumAbs += $errAbs;
    $sumSigned += $errSigned;
#    print STDERR "DEBUG: sumAbs=$sumAbs ; sumSigned=$sumSigned\n";
    if (defined($details)) {
	$details->{sum1} += $content1->[$i];
	$details->{sum2} += $content2->[$i];
    }
}
close(FILE) if (defined($indivFile));

if (defined($details)) {
    $details->{mean1} = $details->{sum1} / scalar(@$content1);
    $details->{mean2} = $details->{sum2} / scalar(@$content2);
#    print STDERR "DEBUG mean1=".$details->{mean1}.", mean2=".$details->{mean2}."\n";
    $details->{meanErrAbs} = $sumAbs / scalar(@$content1);
    $details->{meanErrSigned} = $sumSigned / scalar(@$content1);
    $details->{maxErrAbs}=-1;
    # additional pass to compute std devs and max err
    my ($sumSqDiff1, $sumSqDiff2, $sumSqDiffErrAbs, $sumSqDiffErrSigned) = (0,0,0,0);
    for (my $i=0; $i < scalar(@$content1); $i++) {
	$sumSqDiff1 += ($content1->[$i] - $details->{mean1})**2;
	$sumSqDiff2 += ($content2->[$i] - $details->{mean2})**2;
#	print STDERR "DEBUG val1=".$content1->[$i].", mean1=".$details->{mean1}.", diff=".($content1->[$i] - $details->{mean1}).", SqDiff=".(($content1->[$i] - $details->{mean1})**2)."\n";
#	print STDERR "DEBUG val2=".$content2->[$i].", mean2=".$details->{mean2}.", diff=".($content2->[$i] - $details->{mean2}).", SqDiff=".(($content2->[$i] - $details->{mean2})**2)."\n";
#	print STDERR "DEBUG ssd1=$sumSqDiff1, ssd2=$sumSqDiff2\n";
	my $errSigned = $content2->[$i] - $content1->[$i];
	my $errAbs = abs($errSigned);
	$details->{maxErrAbs} = $errAbs if ($details->{maxErrAbs}<$errAbs);
	$sumSqDiffErrSigned += ($errSigned - $details->{meanErrSigned})**2;
	$sumSqDiffErrAbs += ($errAbs - $details->{meanErrAbs})**2;
    }
    $details->{sd1} = sqrt($sumSqDiff1 /  scalar(@$content1));
    $details->{sd2} = sqrt($sumSqDiff2 /  scalar(@$content2));
#    print STDERR "DEBUG sd1=".$details->{sd1}.", sd2=".$details->{sd2}."\n";
    $details->{sdErrSigned} = sqrt($sumSqDiffErrSigned /  scalar(@$content1));
    $details->{sdErrAbs} = sqrt($sumSqDiffErrAbs /  scalar(@$content1));
    print "Data\tdata1\tdata2\n";
    printf( "mean\t%08.5f\t%08.5f\n", $details->{mean1}, $details->{mean2});
    printf( "sd\t%08.5f\t%08.5f\n\n", $details->{sd1}, $details->{sd2});
    my ($sd1, $sd2) = ($details->{sd1}, $details->{sd2});
    warn "Warning: stddev data 1 is zero! (file $param1)" if ($sd1==0);
    warn "Warning: stddev data 2 is zero! (file $param2)" if ($sd2==0);
    print "Errors\trawValue\tpropSD1\tpropSD2\n";
    _printWithProps("MSE", $details->{meanErrSigned}, $sd1, $sd2);
    _printWithProps("MAE", $details->{meanErrAbs}, $sd1, $sd2);
    _printWithProps("maxAE", $details->{maxErrAbs}, $sd1, $sd2);
    _printWithProps("sdSE", $details->{sdErrSigned}, $sd1, $sd2);
    _printWithProps("sdAE", $details->{sdErrAbs}, $sd1, $sd2);

} else {
    my $mae = $sumAbs / scalar(@$content1);
    printf("%06.3f\n", $mae);
}


sub _printWithProps {
    my ($name, $val, $sd1, $sd2) = @_;
    my $strSD1 = ($sd1 != 0) ? sprintf("%08.5f", $val/$sd1) : "  NA  ";
    my $strSD2 = ($sd2 != 0) ? sprintf("%08.5f", $val/$sd2) : "  NA  ";
    printf( "$name\t%08.5f\t$strSD1\t$strSD2\n", $val);
}
 
