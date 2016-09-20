#!/bin/bash

# weka.jar (and any other java libs) must be in CLASSPATH

progName="weka-training.sh"
javaMem="1024m"

function usage {
    echo
    echo "Syntax: $progName <classifer class and options> <training set (arff)> <model output filename>"
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
if [ $# -ne 3 ]; then
    echo "Error: 3 parameters expected, $# found." 1>&2
    usage 1>&2
    exit 1
fi
classifier="$1"
trainingSet="$2"
outputModel="$3"

echo "** Training on '$trainingSet' using '$classifier', model written to '$outputModel'..."
java -Xms$javaMem -Xmx$javaMem  $classifier -t "$trainingSet" -T "$trainingSet" -d "$outputModel"
echo "** Done"
