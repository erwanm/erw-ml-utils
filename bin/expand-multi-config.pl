#!/usr/bin/perl



use strict;
use warnings;
use Getopt::Std;
use Carp;
use Log::Log4perl;
use CLGTextTools::Commons qw/readConfigFile rankWithTies/;
use CLGTextTools::Stats qw/pickInList pickInListProbas/;
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
