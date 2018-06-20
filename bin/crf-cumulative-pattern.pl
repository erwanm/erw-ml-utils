#!/usr/bin/perl

# EM June 2018
#
#


use strict;
use warnings;
use Carp;
use Getopt::Std;
use Data::Dumper;

binmode(STDOUT, ":utf8");

my $progname = "crf-cumulative-pattern.pl";

my $singleNSize=0;
    
sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <col1>:<Wu1:Nu1>[:Wb1:Nb1][:L|C|R] [ <col2>:<Wu2:Nu2>[:Wb2:Nb2][:L|C|R] ... ]\n";
	print $fh "\n";
 	print $fh "  Generates a pattern file usable with sequential CRF tools, e.g. CRF++ or Wapiti.\n";
	print $fh "  For every selected column <colX>, cumulative <N>-grams, i.e. including every\n";
	print $fh "  size 1 <= N'<= N, are generated over a window of size <W>. \n";
 	print $fh "  Output printed to STDOUT by default (see also -o).\n";
 	print $fh "\n";
 	print $fh "  For each column (or set of columns), an argument has the following format:\n";
 	print $fh "    - <colX> specifies the column number (1-based index). A set can be supplied\n";
	print $fh "      using '-' for a range and ',' as a separator: 2,4-7,9 = columns 2,4,5,6,9.\n";
 	print $fh "    - the <WuX,NuX> part is mandatory and specifies the window size and max\n";
	print $fh "      N-gram size for unigram features.\n";
 	print $fh "    - the <WbX,NbX> part is optional and specifies the window and max N-gram\n";
	print $fh "      size for bigram features (see remark below); default: '0:0' (none).\n";
	print $fh "    - the optional [L|C|R] part specifies whether the current token should be\n";
	print $fh "      set as the leftmost (L), the centre (C) or the rightmost (R) token of the\n";
	print $fh "      window (i.e. with L (resp. R) only the following (resp. previous) tokens\n";
	print $fh "      are taken into account). Default: centre.\n";
 	print $fh "\n";
	print $fh "  Remark: unigram (first part, mandatory) and bigram (second part, optional)\n";
	print $fh "    refer to labels unigrams/bigrams, not input features unigrams/bigrams\n";
 	print $fh "    (see CRF++ documentation: https://taku910.github.io/crfpp/#format); bigram\n";
 	print $fh "    features are computationally expensive, use with caution.\n";
 	print $fh "\n";
 	print $fh "  Options:\n";
	print $fh "    -h print this help message.\n";
	print $fh "    -s single n-gram size: do not use cumulative n-grams.\n";
	print $fh "    -o <output filename> writes output to this file.\n";
 	print $fh "\n";
}




sub generate {
    my ($BorU, $ngramSize, $windowSize, $colOffset, $posCurrent) = @_;

    if ($windowSize>0) {
	die "Error: window size = $windowSize < ngramSize = $ngramSize" if ($windowSize < $ngramSize);
	my $name = "${BorU}W${windowSize}N${ngramSize}C${colOffset}";

#	$windowSize = $windowSize - $ngramSize +1;
	my ($wleft,$wright);
	if ($posCurrent eq "L") {
	    $wleft=0;
	    $wright=$windowSize-1;
	} elsif ($posCurrent eq "R") {
	    $wleft=$windowSize-1;
	    $wright=0;
	} elsif ($posCurrent eq "C") {
	    $wleft=int($windowSize/2);
	    $wright=int($windowSize/2);
	    $wright-- if ($windowSize % 2 == 0); # size of the window = wleft + wright + 1 for current token
	} else {
	    die "Bug generate posCurrent = '$posCurrent'";
	}

	for (my $posNGramStart=-$wleft; $posNGramStart<=$wright-$ngramSize+1; $posNGramStart++) {
	    my $nameThis = $name . ( ($posNGramStart == 0) ? "X0" : ( ($posNGramStart < 0) ?  "L".(-$posNGramStart) : "R".$posNGramStart ) );
	    print generateSingleNGram($nameThis, $BorU, $ngramSize, $colOffset, $posNGramStart)."\n";
	}
#	for (my $l=$wleft; $l>=1; $l--) {
#	    print generateSingleNGram($name."L".$l, $BorU, $ngramSize, $colOffset, -$l)."\n";
#	}
#	print generateSingleNGram($name."X0", $BorU, $ngramSize, $colOffset, 0)."\n";
#	for (my $r=1; $r<=$wright; $r++) {
#	    print generateSingleNGram($name."R".$r, $BorU, $ngramSize, $colOffset, $r)."\n";
#	}
#	print "\n";
    }
}



sub generateSingleNGram {

    my ($name, $BorU, $nsize, $col, $start) = @_;

    my @featParts;
    for (my $n=$start; $n<$start+$nsize; $n++) {
	push(@featParts, "%X[$n,$col]");
    }
    return "$BorU:$name = ".join("/", @featParts);
}


sub parseRangeValues {
    my ($s, $decrementColNo) = @_;

    my @res;
    my @parts = split(/,/, $s);
    foreach my $part (@parts) {
	if ($part =~ m /-/) {
	    my ($first, $last) = ($part =~ m/^(.*)-(.*)$/);
	    die "Format error in '$s'" if (!defined($first) || !defined($last));
	    for (my $i=$first; $i<=$last; $i++) {
		push(@res, $decrementColNo ? $i-1 : $i);
	    }
	} else {
	    push(@res, $decrementColNo ? $part-1 : $part);
	}
    }
    @res = sort { $a <=> $b } @res;
    return \@res;
}


#
# returns a hash ref $colParam containing:
#   - $colParam->{columns} = [ col1, col2, ... ] = columns to which this applies, 0-based indexes
#   - $colParam->{Wu} = window length unigram
#   - $colParam->{Nu} = ngram length unigram
#   - $colParam->{Wb} = window length bigram
#   - $colParam->{Nb} = ngram length bigram
#   - $colParam->{posCurrent} = position (int) of the current token in the window (0= first position)
#
sub parseColumnFormat {
    my ($s) = @_;

    my $res = {};
    my @parts = split(/:/, $s);
    # default Wb,Nb
    $res->{columns} = parseRangeValues($parts[0], 1);
    $res->{Wu} = $parts[1];
    $res->{Nu} = $parts[2];
    if ((scalar(@parts) == 3) || (scalar(@parts) == 4)) {
	$res->{Wb} = 0;
	$res->{Nb} = 0;
	$res->{posCurrent} = (scalar(@parts) == 3) ? "C"  : $parts[3];
    } elsif (scalar(@parts) == 5) {
	# default position
	$res->{posCurrent} = "C";
    } elsif (scalar(@parts) == 6) {
	# default position
	$res->{Wb} = $parts[3];
	$res->{Nb} = $parts[4];
	$res->{posCurrent} = $parts[5];
    } else {
	die "Error: column parameter '$s' does not follow the pattern '<col>:<Wu:Nu>[:Wb:Nb][:L|C|R]'";
    }
    die "Error: invalid value as last part in '$s', should be L, R or C" if ($res->{posCurrent} !~ m/^[LCR]$/);
    return $res;
}






#
# called with either parameters for unigrams or bigrams
#
#
sub generatePatterns {
    my ($BorU, $windowSize, $ngramSize, $colOffset, $posCurrent) = @_;

    if ($singleNSize) {
	generate($BorU, $ngramSize, $windowSize, $colOffset, $posCurrent);
    } else {
	for (my $n=1; $n<=$ngramSize; $n++) {
	    generate($BorU, $n, $windowSize, $colOffset, $posCurrent);
	}
    }
}



sub generatePatternFile {
    my @colParams = @_;

    foreach my $colParam (@colParams) {
	foreach my $colOffset (@{$colParam->{columns}}) {
	    generatePatterns("U", $colParam->{Wu}, $colParam->{Nu}, $colOffset, $colParam->{posCurrent});
	    generatePatterns("B", $colParam->{Wb}, $colParam->{Nb}, $colOffset, $colParam->{posCurrent});
	}
    }
    
}



# PARSING OPTIONS
my %opt;
getopts('hso:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage(*STDOUT) && exit 0 if $opt{h};
print STDERR "At least one argument expected"  && usage(*STDERR) && exit 1 if (scalar(@ARGV) < 1);


$singleNSize = $opt{s};
my $outputFilename = $opt{o};

my $fh;
if ($outputFilename) {
    open $fh, '>', $outputFilename;
    select $fh; # redirects STDOUT to this file
}


my @colParams = map { parseColumnFormat($_) } @ARGV;

#print Dumper(\@colParams);
generatePatternFile(@colParams);


