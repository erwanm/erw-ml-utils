#!/usr/bin/perl

# update July 18: added the functions from CLGTextTools (not great but more convenient)

use strict;
use warnings;
use Getopt::Std;
use Carp;
use Log::Log4perl;
#use CLGTextTools::Commons qw/readConfigFile rankWithTies/;
#use CLGTextTools::Stats qw/pickInList pickInListProbas/;
use Data::Dumper;

my $progName="expand-multi-config.pl";


# WARNING: use of global variables!
my $suffix=".conf";
my $nbTotal=0;
my $currentIndex=0;
my $nbDigits=0;
my $outputPrefix="";
my $explicitName=undef;
my $printConfigFilenames=undef;

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: $progName [options] <output prefix>\n";
	print $fh "\n";
	print $fh "   Reads a list of multi-config files from STDIN;\n";
	print $fh "   Given a multi-config file with lines like:\n";
	print $fh "     key1=valA1 valB1\n";
	print $fh "     key2=valA2 valB2 valC2 valD2\n";
	print $fh "     key3=valA3\n";
	print $fh "   creates all the possible combinations of values, e.g.:\n";
	print $fh "     key1=valA1\n";
	print $fh "     key2=valB2\n";
	print $fh "     key3=valA3\n";
	print $fh "   in files named <output prefix><config no>.conf\n";
	print $fh "   <output prefix> can contain a path.\n";
	print $fh "   lines starting with '#' or empty are ignored.\n";
	print $fh "\n";
	print $fh "   Options:\n";
	print $fh "     -h print this help\n";
	print $fh "     -s <suffix> ti used instead of '.conf'\n";
	print $fh "     -e explicit name '<key1><val1-<key2><val2>-...' for the output files\n";
	print $fh "        caution: long filenames.\n";
	print $fh "     -p print the filenames of the output configs, one by line.\n";
	print $fh "     -r <nb> instead of generating the exhaustive set of possible configs,\n";
	print $fh "        olny generate <nb> random configs.\n";
	print $fh "     -g <prev gen>:<population>:<prop breeders>:<prob mutation>:<prop elit>:<prop random>\n";
	print $fh "        use genetic algorithm based on the previous generation of configs described\n";
	print $fh "        in the file <prev gen> as lines <config file> <performance>.\n";
	print $fh "        <prop breeders> = proportion of indivuals to select from the prev gen;\n";
	print $fh "                          (cannot be higher than 0.5)\n";
	print $fh "        <prob mutation> = probablity of a mutation on one gene;\n";
	print $fh "           Remark: this is actually the probability of a new random value, which can\n";
	print $fh "                    end up being one the parents values.\n";
	print $fh "        <prop elit> = prop of the new generation taken as is from the top prev gen;\n";
	print $fh "        <prop random> = prop of the new generation selected totally randomly.\n";
	print $fh "        The genetic process has typically been initialized using '-r' option.\n";

	print $fh "\n";
}




#twdoc readConfigFile($filename)
#
# Reads a UTF8 text "config" file, i.e. with lines of the form ``paramName=value``. Comments (starting with #) and empty lines are ignored.
#
# * returns a hash ``res->{paramName} = value``
#
#/twdoc
sub readConfigFile {
    my $filename=shift;
    open( FILE, '<:encoding(UTF-8)', $filename ) or die "Cannot read config file '$filename'.";
    my %res;
    local $_;
    while (<FILE>) {
	#print "debug: $_";
	chomp;
	if (m/#/) {
	    s/#.*$//;  # remove comments
	}
	s/^\s+//; # remove spaces
	s/\s+$//;
	if ($_) {
	    my ($name, $value) = ( $_ =~ m/([^=]+)=(.*)/);
	    $res{$name} = $value;
	    #print "debug: '$name'->'$value'\n";
	}
    }
    close(FILE);
    return \%res;
}



#twdoc rankWithTies($parameters)
#
# Computes a ranking which takes ties into account, i.e. two identical values are assigned the same rank.
# The sum property is also fulfilled, i.e. the sum of all ranks is always 1+2+...+N (if first rank is 1). This implies
# that the rank assigned to several identical values is the average of the ranks they would have been assigned if ties were not taken into account.
#
# ``$parameters`` is a hash which must define:
# * values: a hash ref of the form ``$values->{id} = value``. Can contain NaN values, but these values will be ignored.
# and optionally defines:
#
# * array: if defined, an array ref which contains the ids used as keys in values
# * arrayAlreadySorted: (only if array is defined, see above). if set to true, "array" must be already sorted. the sorting step
#   will not be done (this way it is possible to use any kind of sorting) (the ranking step - with ties - is still done of course)
# * highestValueFirst: false by default. set to true in order to rank from highest to lowest values. Useless if array is defined.
# * printToFileHandle: if defined, a file handle where ranks will be printed.
# * dontPrintValue: if defined and if printToFileHandle is defined, then lines are of the form ``<id> [otherData] <rank>"  instead of "<id> [otherData] <value> <rank>``.
#
# * otherData: hash ref of the form ``$otherData->{$id}=data``. if defined and if printToFileHandle is defined, then lines
#   like ``<id> <otherData> [value] <rank>`` will be written to the file instead of ``<id> [value] <rank>``. if the "data" contains
#   several columns, these columns must be already separated together but should not contain a column separator at the beginning
#   or at the end.
# * columnSeparator: if defined and if printToFileHandle is defined, will be used as column separator (tabulation by default).
# * noNaNWarning: 0 by default, which means that a warning is issued if NaN values are found. This does not happen if this parameter
#   is set to true. not used if $array is defined.
# * dontStoreRanking: By default the returned value is a hash ref of the form ``$ranking->{id}=rank`` containing the whole ranking.
#  If dontStoreRanking is true then nothing is returned.
# * firstRank: rank starting value (1 by default).
# * addNaNValuesBefore: boolean, default 0. by default NaN values are discarded. If true, these values are prepended to the ranking (before first real value).
# * addNaNValuesAfter: boolean, default 0. by default NaN values are discarded. If true, these values are appended to the ranking (after last real value).
#
#/twdoc
sub rankWithTies {

    my ($parameters, $logger) = @_;
    my $firstRank = defined( $parameters->{firstRank} ) ? $parameters->{firstRank} : 1;
    my $colSep = defined( $parameters->{columnSeparator} ) ? $parameters->{columnSeparator} : "\t";
    my $values = $parameters->{values};
    confessLog($logger, "Error: \$parameters->{values} must be defined.") if ( !defined($values) );
    my $array = $parameters->{array};
    if ( !defined($array) || !$parameters->{arrayAlreadySorted} ) {
	my @sortedIds;
	if ( $parameters->{highestValueFirst} ) {
	    $logger->debug("Sorting by descending order (highest value first)") if ($logger);
	    @sortedIds =
		sort { $values->{$b} <=> $values->{$a} }
	    grep { $values->{$_} == $values->{$_} }
	    defined($array)
		? @$array
		: keys %$values
		; # tricky: remove the NaN values before sorting. found in perl man page for sort.
	} else {
	    $logger->debug("Sorting by ascending order (lowest value first)") if ($logger);
	    @sortedIds =
		sort { $values->{$a} <=> $values->{$b} }
	    grep { $values->{$_} == $values->{$_} }
	    defined($array)
		? @$array
		: keys %$values
		; # tricky: remove the NaN values before sorting. found in perl man page for sort.
	}
	if (   $parameters->{addNaNValuesBefore} || $parameters->{addNaNValuesAfter} ) {
	    my @NaNIds =
		grep { $values->{$_} != $values->{$_} }
	    defined($array) ? @$array : keys %$values;
	    my $nbValues    = scalar( keys %$values );
	    my $nbNaNValues = scalar(@NaNIds);
	    if ( scalar($nbNaNValues) > 0 ) {
		if ( $parameters->{addNaNValuesBefore} ) {
		    unshift( @sortedIds, @NaNIds );
		    if ( !$parameters->{noNaNWarning} ) {
			if ($logger) {
			    $logger->logwarn("$nbNaNValues NaN values (among $nbValues) prepended to ranking.") ;
			} else {
			    warn("$nbNaNValues NaN values (among $nbValues) prepended to ranking.") ;
			}
		    }
		}
		else {
		    push( @sortedIds, @NaNIds );
		    if ( !$parameters->{noNaNWarning} ) {
			if ($logger) {
			    $logger->logwarn(
				"$nbNaNValues NaN values (among $nbValues) appended to ranking."
				) ;
			} else {
			    warn "$nbNaNValues NaN values (among $nbValues) appended to ranking.";
			}
		    }
		}
	    }
	}
	elsif ( !$parameters->{noNaNWarning} ) {
	    my $nbValues    = scalar( keys %$values );
	    my $nbNaNValues = $nbValues - scalar(@sortedIds);
	    warnLog($logger, "$nbNaNValues NaN values (among $nbValues) discarded from ranking." ) if ( $nbNaNValues > 0 );
	}
	$array = \@sortedIds;
    }
    my %ranks;
    my $i       = 0;
    my $fh      = $parameters->{printToFileHandle};
    my $ranking = undef;
    while ( $i < scalar(@$array) ) {
	my $currentFirst = $i;
	my $nbTies       = 0;
	while (( $i + 1 < scalar(@$array) )
	       && ( $values->{ $array->[$i] } == $values->{ $array->[ $i + 1 ] } )
	    )
	{
	    $nbTies++;
	    $i++;
	}
	my $rank = ( ( 2 * ( $currentFirst + $firstRank ) ) + $nbTies ) / 2;
	for ( my $j = $currentFirst ; $j <= $currentFirst + $nbTies ; $j++ ) {
	    $ranks{ $array->[$j] } = $rank;
	    if ( defined($fh) ) {
		my $otherData =  defined( $parameters->{otherData} ) ? $colSep . $parameters->{otherData}->{ $array->[$j] } : "";
		my $valueData =  $parameters->{dontPrintValue}  ? "" : $colSep . $values->{ $array->[$j] };
		print $fh $array->[$j] . $otherData . $valueData . $colSep . $rank . "\n";
	    }
	    if ( !$parameters->{dontStoreRanking} ) {
		$ranking->{ $array->[$j] } = $rank;
	    }
	}
	$logger->debug("found $nbTies ties starting at position $currentFirst+1, assigned rank is $rank") if ($logger);
	$i++;
    }
    return $ranking if ( !$parameters->{dontStoreRanking} );

}



#twdoc pickInList(@$list)
#
# picks randomly a value in a list.
# Uniform probability distribution over cells (thus a value occuring twice is twice more likely to get picked than a value occuring only once).
# Fatal error if the array is empty.
#
#/twdoc
sub pickInList {
    my $list = shift;
    #print Dumper($list);
    confess "Wrong parameter: not an array or empty array" if ((ref($list) ne "ARRAY") || (scalar(@$list)==0));
    return $list->[int(rand(scalar(@$list)))];
}



#twdoc pickIndex(@$list)
#
# picks an index randomly in a list, i.e. simply returns an integer between 0 and n-1, where n is the size of the input list.
#
#/twdoc
#
sub pickIndex {
    my $list = shift;

    confess "Wrong parameter: not an array or empty array" if ((ref($list) ne "ARRAY") || (scalar(@$list)==0));
    my $n = scalar(@$list);
    return int(rand(scalar(@$list)));
}


#twdoc pickInListProbas(%$hash)
#
# picks a random value among (keys %$hash) following, giving each key a probability proportional to $hash->{key} w.r.t to all values in (values %$hash)
# Remark: method is equivalent to scaling the sum of the values (values %$hash) to 1, as if these represented a stochastic vector of probabilities.
# Fatal error if the array is empty.
#
#/twdoc
sub pickInListProbas {
    my $areaByValue = shift;
    confess "Wrong parameter: not a hash or empty hash" if ((ref($areaByValue) ne "HASH") || (scalar(keys %$areaByValue)==0));
    my $areaTotal = 0;
    while (my ($item, $area) = each %$areaByValue) {
	$areaTotal += $area;
	#    print STDERR "DEBUG $item : $area (total = $areaTotal)\n";
    }
    my $rndProba = rand($areaTotal);
    $areaTotal = 0;
    while (my ($item, $area) = each %$areaByValue) {
	$areaTotal += $area;
	#    print STDERR "DEBUG $item : $area (total = $areaTotal, random = $rndProba)\n";
	return $item if ($rndProba < $areaTotal);
    }
    die "BUG should never have arrived here";
}



    


sub writeConfig {
    my ($config, $id) = @_;

#    print STDERR "DEBUG writeConfig: config=\n";
#    print STDERR Dumper($config);
    my $content="";
    my @filenameList;
    foreach my $key (sort keys %$config) {
	$content .= "$key=".$config->{$key}."\n";
	push(@filenameList, $key.$config->{$key}) if  ($explicitName);
    }
    my $filename = "$outputPrefix";
    if ($explicitName) {
	$filename .= join("-", @filenameList).$suffix;
    } else {
	my $idStr = sprintf("%0${nbDigits}d", $id);
	$filename .= "${idStr}${suffix}";
    }
#	print STDERR "DEBUG: done filename=$filename\n";
    open(FILE, ">", $filename) or confess "Can not write to file '$filename'";
    print FILE "$content";
    close(FILE);
    print "$filename\n" if ($printConfigFilenames);
}


sub writeAllCombinations {
    my ($config, $keys, $currentConfig) = @_;
    if (scalar(@$keys) > 0) {
#	print STDERR "DEBUG: not done; keys = ".join(",", @$keys)." ; currentConfig=\n";
#	print STDERR Dumper($currentConfig);
	my @localKeys = @$keys;
	my $key = shift(@localKeys);
	foreach my $value (@{$config->{$key}}) {
	    my %myConfig = %$currentConfig;
	    $myConfig{$key} = $value;
	    writeAllCombinations($config, \@localKeys, \%myConfig);
	}
    } else {
	writeConfig($currentConfig, $currentIndex++);
    }
}


sub writeRandomCombinations {
    my ($multiConfig, $keys, $nb) = @_;
    
    for (my $i=0; $i<$nb; $i++) {
	my %newConfig;
	foreach my $key (@$keys) {
	    my $value=pickInList($multiConfig->{$key});
	    $newConfig{$key} = $value;
	}
	writeConfig(\%newConfig, $currentIndex++);
    }
}


# proba selection based on rank!
#
sub selectBreeders {
    my ($prevGenConfigs, $prevGenPerfs, $size, $propBreeders, $elitSize) = @_;
#    my $nbBreeders = int(scalar(@prevGen) * $propBreeders + 0.5);
    my $prevSize  = scalar(@$prevGenConfigs);
    my $ranking = rankWithTies({ values => $prevGenPerfs, noNaNWarning => 1 });

    # the probabilty is computed from the ranking "with ties", which is more accurate,
    # but for elite configs we need to pick the exact number, which means that we cannot
    # rely on the rank "with ties" for that.
    # REMARK: in case of a tie spanning over the threshold, this method doesn't pick
    #  elite configs randomly, but: 
    # 1) it doesn't matter too much, since the order in the previous generation was (mostly) random
    # 2) interestingly, the order depends on Perl's hashing, so for one specific list the order is
    #    deterministic but doesn't depend on the order in the previous generation (i.e. it's not always
    #    the first found)
    # REMARK: with this method the order of elite configs in a generation is not random
    my @elite;
    my @idsByReverseScore = sort  { $ranking->{$b} <=> $ranking->{$a} } keys %$ranking;
    for (my $i=0; $i<$elitSize; $i++) {
	my $index = $idsByReverseScore[$i];
#	print STDERR "DEBUG ELITE $i: index=$index, perf=".$prevGenPerfs->{$index}."; rank=".$ranking->{$index}."; relrank=".($ranking->{$index} / $prevSize)."\n";
	push(@elite, $prevGenConfigs->[$index]);
    }

    my @breeders;
    for (my $i=0; $i<$prevSize; $i++) {
	# relative rank * propBreeders  * 2 (because average proba based on relative rank = 0.5)
	my $probaSelected = $ranking->{$i} / $prevSize * $propBreeders *2;
#	print STDERR "DEBUG index=$i, perf=".$prevGenPerfs->{$i}."; rank=".$ranking->{$i}."; relrank=".($ranking->{$i} / $prevSize)."; proba=$probaSelected\n";
	if (rand() < $probaSelected) {
	    push(@breeders, $prevGenConfigs->[$i]); 
#	    print STDERR "  selected for breeders\n";
	}
    }
#    print STDERR "BREEDERS:\n";
#    print STDERR Dumper(\@breeders);
    return (\@breeders, \@elite);
}


sub crossover {
    my ($multiConfigs, $multiConfigIdToNb, $probaMutation, $parent1, $parent2) = @_;

    my $keys = $multiConfigs->[0]->{keys}; # this is in case something has changed (new key that the parents didn't have) - not very standard but does not change anything if there's no new key
#    print STDERR Dumper($multiConfigs);
    my %baby;
    foreach my $key (@$keys) {
#	print STDERR "DEBUG crossover key=$key\n";
	if ((rand() < $probaMutation) || (!defined($parent1->{$key}) && !defined($parent2->{$key}))) { # mutation, picking value at random
	    my $mcId = pickInListProbas($multiConfigIdToNb);
#	    print STDERR "DEBUG crossover key=$key, mutation; mcId=$mcId, parents value: ".$parent1->{$key}.";".$parent2->{$key}."\n";
	    $baby{$key} = pickInList($multiConfigs->[$mcId]->{multiConf}->{$key});
	} elsif (defined($parent1->{$key}) && defined($parent2->{$key})) { # normal case
	    $baby{$key} = (rand()<0.5) ? $parent1->{$key} :  $parent2->{$key} ;
	} elsif (defined($parent1->{$key}) && !defined($parent2->{$key})) { # strange case (?)
	    $baby{$key} = $parent1->{$key} ;
	} elsif (!defined($parent1->{$key}) && defined($parent2->{$key})) { # strange case (?)
	    $baby{$key} = $parent2->{$key} ;
	} # no other possibility
    }

    return \%baby;
}


sub writeGeneticCombinations {
    my ($params, $multiConfigs) = @_;
    my @prevGenConfigs;
    my %prevGenPerf;
    open(FILE, "<", $params->{prevGenFile}) ||  die "$progName: Cannot open file '".$params->{prevGenFile}."'";
#    print STDERR Dumper($multiConfigs);
    while (<FILE>) {
	chomp;
	my ($configFile, $perf) = split("\t", $_);
	my $config = readConfigFile($configFile);
	push(@prevGenConfigs, $config);
	$prevGenPerf{scalar(@prevGenConfigs)-1} = $perf;
    }
    close(FILE);
    my $avgNbBreeders = scalar(@prevGenConfigs) * $params->{propBreeders};
    die "$progName error: genetic algorithm: the average number of breeders is too low: $avgNbBreeders (previous population=".scalar(@prevGenConfigs)."; prop. breeders=".$params->{propBreeders}.")" if ($avgNbBreeders<3);
    warn "$progName warning: genetic algorithm: the average number of breeders is only $avgNbBreeders (previous population=".scalar(@prevGenConfigs)."; prop. breeders=".$params->{propBreeders}.")" if ($avgNbBreeders<6);
 #   print STDERR "DEBUG: avgNbBreeders=$avgNbBreeders\n";
    my $elitSize = int($params->{populationSize} * $params->{propElit} + 0.5);
    my ($breeders, $elite);
    do {
	($breeders, $elite) = selectBreeders(\@prevGenConfigs, \%prevGenPerf, $params->{populationSize}, $params->{propBreeders}, $elitSize);
#	print STDERR "DEBUG breeders = ".scalar(@$breeders)."\n"; 
    } until (scalar(@$breeders)>=2) ; # re-try in case not enough breeders (we have died already if the avg number is lower than 3, so it should not loop too long hopefully)
    # random
    my $randomSize = int($params->{populationSize} * $params->{propRandom} + 0.5);
    if ($randomSize >0) {
	foreach my $mc (@$multiConfigs) {
	    my $nb = int($randomSize * $mc->{nb} / $nbTotal +0.5);
#	    print STDERR "DEBUG RANDOM: randomSize=$randomSize; mc->nb=".$mc->{nb}."; nbTotal=$nbTotal; nb=$nb; currentIndex=$currentIndex\n";
	    writeRandomCombinations($mc->{multiConf}, $mc->{keys}, $nb);
	}
    }
    # elite
    foreach my $eliteConfig (@$elite) {
#	    print STDERR "DEBUG ELITE:  currentIndex=$currentIndex\n";
	writeConfig($eliteConfig, $currentIndex++);
    }
    # regular
    my %multiConfigIdToNbCases;
    for (my $i=0; $i<scalar(@$multiConfigs); $i++) { # over-complicated and maybe not very good, but well
	$multiConfigIdToNbCases{$i} = $multiConfigs->[$i]->{nb};
    }
    my $nbRegular = $params->{populationSize} - $elitSize - $randomSize;
#    print STDERR "DEBUG $progName elitSize=$elitSize; randomSize=$randomSize; nbRegular=$nbRegular\n";
    for (my $i=0; $i< $nbRegular; $i++) {
	my $parent1 = pickInList($breeders);
	my $parent2 = pickInList($breeders);
	my $baby = crossover($multiConfigs, \%multiConfigIdToNbCases, $params->{probaMutation}, $parent1, $parent2);
	writeConfig($baby, $currentIndex++);
    }
    
    }


# PARSING OPTIONS
my %opt;
getopts('hs:epr:g:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "1 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 1);
$suffix=$opt{s} if (defined($opt{s}));
$explicitName=defined($opt{e});
$printConfigFilenames=defined($opt{p});
my $geneticAlgoParams;
if (defined($opt{g})) {
    my $strParam=$opt{g} ;
    my @params = split(":", $strParam);
    die "$progName error: -g requires 6 ':'-separated arguments " if (scalar(@params) != 6);
    ($geneticAlgoParams->{prevGenFile},
	$geneticAlgoParams->{populationSize},
	$geneticAlgoParams->{propBreeders},
	$geneticAlgoParams->{probaMutation}, 
	$geneticAlgoParams->{propElit}, 
	$geneticAlgoParams->{propRandom} ) = @params;
}



$outputPrefix=$ARGV[0];
my $randomNb=$opt{r};


my @multiConfigs;
# read multi-config files
while (<STDIN>) {
    chomp;
    my $multiConf = readConfigFile($_);
    my $nbThis=1;
    my @keys;
    foreach my $key (sort keys %$multiConf) {
	push(@keys, $key);
	my @values = split(/\s+/, $multiConf->{$key});
	$nbThis *= scalar(@values);
	$multiConf->{$key} = \@values;
#    print STDERR "DEBUG: key $key values = ( ".join(" , ", @values)." ) ; nb=$nb\n";
    }
    push(@multiConfigs, {multiConf=>$multiConf, keys=>\@keys, nb=>$nbThis});
    $nbTotal += $nbThis;
}
print STDERR "$progName info: $nbTotal possible configs\n";

if (defined($randomNb)) { # random 
    $nbDigits=length($randomNb);
    foreach my $mc (@multiConfigs) {
	writeRandomCombinations($mc->{multiConf}, $mc->{keys}, int($randomNb * $mc->{nb} / $nbTotal +0.5));
    }
} elsif (defined($geneticAlgoParams)) { # genetic
    $nbDigits=length($geneticAlgoParams->{populationSize})+1; # +1 because the size can be higher (statistical avg)
    writeGeneticCombinations($geneticAlgoParams, \@multiConfigs);
} else { # exhaustive!
    $nbDigits=length($nbTotal);
#    print STDERR "DEBUG nbDigits=$nbDigits\n";
    foreach my $mc (@multiConfigs) {
	writeAllCombinations($mc->{multiConf}, $mc->{keys}, {});
    }
}
