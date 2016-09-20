#!/bin/bash

# weka.jar (and any other java libs) must be in CLASSPATH

progName="weka-predict.sh"
javaMem="1024m"

function usage {
    echo
    echo "Syntax: $progName <classifer class and options> <test set (arff)> <model input filename> <prediction output filename>" 
    echo
    echo "Options:"
    echo "  -h this help message"
    echo "  -m <java mem> amount of memory for the JVM. Default: $javaMem."
    echo
}


while getopts 'hm:' option ; do
    case $option in
	"h" ) usage
	      exit 0;;
	"m" ) javaMem=$OPTARG;;
        "?" )
            echo "Error, unknow option." 1>&2
            usage 1>&2
	    exit 1
    esac
done
shift $(($OPTIND - 1)) # skip options already processed above
if [ $# -ne 4 ]; then
    echo "Error: 4 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
classifier="$1"
testSet="$2"
model="$3"
output="$4"
echo "** Predicting on '$testSet' using model '$model', classifier '$classifier', and writing to $output..."
#java -Xms$javaMem -Xmx$javaMem  $classifier -T "$testSet" -l "$model" -p 0
java -Xms$javaMem -Xmx$javaMem  weka.filters.supervised.attribute.AddClassification -serialized "$model" -classification -remove-old-class -i "$testSet" -o "$output" -c last
echo "** Done"
