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

my $progname = "crf-generate-multi-config.pl";

my $defaultPosCurrent="C";
my $combineBigrams=0;

my %fixedParams = ( "crftool" => "crf++ wapiti",
		    "wapiti.algo" => "l-bfgs sgd-l1 bcd rprop rprop+ rprop-",
		    "wapiti.sparse" => "0 1",
		    "crfpp.cost" => "0.01 0.1 1 10 100",
		    "crfpp.minfreq" => "1 3 5 10 25",
		    "crfpp.algo" => "CRF MIRA",
		    "pattern.singleNGramSize" => "0"
    );
my $columnPrefix="col.";
    
sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <col1>:<Wu1:Nu1>[:Wb1:Nb1][:L?C?R?] [ <col2>:<Wu2:Nu2>[:Wb2:Nb2][:L?C?R?] ... ]\n";
	print $fh "\n";
 	print $fh "  Generates a multi-config file (usable with 'expand-multi-config.pl') which\n";
	print $fh "  describes a range of options for training a sequential CRF model with CRF++\n";
	print $fh "  or Wapiti. the generated multi-config file can easily be modified manually.\n";
	print $fh "  The resulting config files can be used with 'crf-train-test.sh', which \n";
	print $fh "  reads the parameters and trains/applies a model following those.\n";
	print $fh "  \n";
	print $fh "  The main parameters are the options which will be used to generate a CRF\n";
	print $fh "  template file with 'crf-cumulative-pattern.pl' (see explanations there).\n";
	print $fh "  for every selected column <colX>, combinations of size (Wu,Nu) are generated\n";
	print $fh "  from (0,0) up to (Wu,Nu); if (Wb,Nb) are specified, an additional variant\n";
	print $fh "  is generated for every (Wu,Nu); the last part specifies the position of the\n";
 	print $fh "  current token in the window, it must include at least one in [LCR] but \n";
	print $fh "  several possibilities are allowed (default: '$defaultPosCurrent').";
 	print $fh "  Output printed to STDOUT by default (see also -o).\n";
 	print $fh "\n";
# 	print $fh "  For each column (or set of columns), an argument has the following format:\n";
#	print $fh "    - <colX> specifies the column number (1-based index). A set can be supplied\n";
#	print $fh "      using '-' for a range and ',' as a separator: 2,4-7,9 = columns 2,4,5,6,9.\n";
# 	print $fh "    - the <WuX,NuX> part is mandatory and specifies the window size and max\n";
#	print $fh "      N-gram size for unigram features.\n";
# 	print $fh "    - the <WbX,NbX> part is optional and specifies the window and max N-gram\n";
#	print $fh "      size for bigram features (see remark below); default: '0:0' (none).\n";
#	print $fh "    - the optional [L|C|R] part specifies whether the current token should be\n";
#	print $fh "      set as the leftmost (L), the centre (C) or the rightmost (R) token of the\n";
#	print $fh "      window (i.e. with L (resp. R) only the following (resp. previous) tokens\n";
#	print $fh "      are taken into account). Default: centre.\n";
 #	print $fh "\n";
#	print $fh "  Remark: unigram (first part, mandatory) and bigram (second part, optional)\n";
#	print $fh "    refer to labels unigrams/bigrams, not input features unigrams/bigrams\n";
 #	print $fh "    (see CRF++ documentation: https://taku910.github.io/crfpp/#format); bigram\n";
 #	print $fh "    features are computationally expensive, use with caution.\n";
 #	print $fh "\n";
 	print $fh "  Options:\n";
	print $fh "    -h print this help message.\n";
	print $fh "    -o <output filename> writes output to this file.\n";
 	print $fh "    -b generate all the combinations of bigrams with unigram patterns, instead\n";
 	print $fh "       of adding a single bigram variant which 'follows' the unigram version.\n";
 	print $fh "    -p <prefix> parameter name prefix for all the generated parameters.\n";
 	print $fh "\n";
}






#
# returns a hash ref $colParam containing:
#   - $colParam->{columns} = range
#   - $colParam->{Wu} = window length unigram
#   - $colParam->{Nu} = ngram length unigram
#   - $colParam->{Wb} = window length bigram
#   - $colParam->{Nb} = ngram length bigram
#   - $colParam->{posCurrent} = [LCR]+
#
sub parseColumnFormat {
    my ($s) = @_;

    my $res = {};
    my @parts = split(/:/, $s);
    # default Wb,Nb
    $res->{columns} = $parts[0];
    $res->{Wu} = $parts[1];
    $res->{Nu} = $parts[2];
    if ((scalar(@parts) == 3) || (scalar(@parts) == 4)) {
	$res->{Wb} = 0;
	$res->{Nb} = 0;
	$res->{posCurrent} = (scalar(@parts) == 3) ? "C"  : $parts[3];
    } elsif ((scalar(@parts) == 5) || (scalar(@parts) == 6)) {
	# default position
	$res->{Wb} = $parts[3];
	$res->{Nb} = $parts[4];
	$res->{posCurrent} = (scalar(@parts) == 5) ? "C" : $parts[5] ;
    } else {
	die "Error: column parameter '$s' does not follow the pattern '<col>:<Wu:Nu>[:Wb:Nb][:L|C|R]'";
    }
    die "Error: invalid value as last part in '$s', should be L, R or C" if ($res->{posCurrent} !~ m/^[LCR]*$/);
    return $res;
}



sub min {
    my ($a, $b) = @_;
    return ($a>$b) ? $b : $a ;
}



# PARSING OPTIONS
my %opt;
getopts('ho:bp:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage(*STDOUT) && exit 0 if $opt{h};
print STDERR "At least one argument expected"  && usage(*STDERR) && exit 1 if (scalar(@ARGV) < 1);


$combineBigrams = $opt{b};
my $outputFilename = $opt{o};
my $paramPrefix=defined($opt{p}) ? $opt{p} : "";

my $fh;
if ($outputFilename) {
    open $fh, '>', $outputFilename;
    select $fh; # redirects STDOUT to this file
}

foreach my $name (keys %fixedParams) {
    print "$paramPrefix$name=$fixedParams{$name}\n";
}

my @colParams = map { parseColumnFormat($_) } @ARGV;

for my $colParam (@colParams) {
#   print Dumper(\$colParam);
    my @paramValues;
    push(@paramValues, "0:0");
    for (my $w=1; $w<=$colParam->{Wu}; $w++) {
	for (my $n=1; ($n<=$w) &&  ($n<=$colParam->{Nu}); $n++) {
#	    print STDERR "$w,$n\n";
	    my @tmpValues;
	    push(@tmpValues, "$w:$n:0:0");
	    if ($combineBigrams) {
		for (my $wb=1; $wb<=$colParam->{Wb}; $wb++) {
		    for (my $nb=1; ($nb<=$wb) &&  ($nb<=$colParam->{Nb}); $nb++) {
			push(@tmpValues, "$w:$n:$wb:$nb");
		    }
		}
	    } else {
		if (($colParam->{Wb}>0) && ($colParam->{Nb}>0)) {
		    my ($wb, $nb) = ( min($colParam->{Wb}, $w) , min($colParam->{Nb}, $n) );
		    push(@tmpValues, "$w:$n:$wb:$nb");
		}
	    }
	    foreach my $v (@tmpValues) {
		for (my $i = 0; $i < length($colParam->{posCurrent}); $i++) {
		    push(@paramValues, $v.":".substr($colParam->{posCurrent}, $i, 1));
		}
	    }
	    
	}
    }
#    print STDERR scalar(@paramValues)."\n";
    print $paramPrefix.$columnPrefix.$colParam->{columns}."=".join(" ", @paramValues)."\n";
}

