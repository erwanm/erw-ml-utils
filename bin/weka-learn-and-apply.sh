#!/bin/bash

# EM Mar 14

progName="weka-learn-and-apply.sh"
saveModel=
applyModel=
wekaStdOut="/dev/null"

# trying this version to avoid random errors when writing to dilly /tmp
# using the env variable as below seems to work, whereas the option passed directly to the JVM doesn't (??)
# minor inconvenient: the JVM always prints the annoying message:
# Picked up _JAVA_OPTIONS: -Djava.io.tmpdir=/experimental/Erwan/tmp
#
export _JAVA_OPTIONS=-Djava.io.tmpdir=$TMPDIR

#javaMem=1024m

function usage {
    echo "Usage: weka-learn-and-apply.sh [options] <class> <trainset arff> <testset arff> <predicted output arff>"
    echo
    echo "  Trains a model using <class> Weka algo and parameters (quoted) on <trainset>,"
    echo "  then applies it to testset and writes the predicted values to <output>."
    echo
    echo "Options:"
    echo "  -h this help message"
    echo "  -k <weka stdout> save weka's output to this file"
    echo "  -p <params> quoted extra parameters for Weka 'class'"
    echo "  -m <model> saves the model to file <model>"
    echo "  -a <model> no training (param <trainset> ignored), only apply the <model> supplied"
    echo "     to <testset arff>."
    echo    
}



function trainAndApply {
    trainArff="$1"
    testArff="$2"
    outputArff="$3"
    class="$4"    
    paramToAddQuoted="$5"
    if [ -z "$applyModel" ]; then # training needed
	model="$saveModel"
	if [ -z "$saveModel" ]; then
	    model=$(mktemp --tmpdir "tmp.$progName.trainAndApply2.XXXXXXXX")
	fi
	stderrTmp=$(mktemp --tmpdir "tmp.$progName.trainAndApply2A.XXXXXXXX")
	if [ -z "$paramToAddQuoted" ]; then # EM April 14: dummy -T option to force no cross-validation during testing
	    java -Djava.io.tmpdir=$TMPDIR $class -t "$trainArff" -T "$testArff" -d "$model" >"$wekaStdOut"  2>"$stderrTmp"
	    status=$?
	else
	    java -Djava.io.tmpdir=$TMPDIR $class "$paramToAddQuoted" -t "$trainArff" -T "$testArff" -d "$model" >"$wekaStdOut"  2>"$stderrTmp"
	    status=$?
	fi
	cat "$stderrTmp" | grep -v "Picked up _JAVA_OPTIONS:" | grep -v "llegal reflective" | grep -v "illegal access operations will be denied" | grep -v "Please consider reporting this" | grep -v "com.github.fommil.netlib" 1>&2
	rm -f "$stderrTmp"
	if [ $status -ne 0 ]; then
	    echo "$progName,$LINENO: weka training returned an error, aborting. trainArff=$trainArff" 1>&2
	    exit 1
	fi
	if [ ! -s "$model" ]; then
	    echo "$progName,$LINENO: weka training did not return a model file '$model', aborting. trainArff=$trainArff" 1>&2
	    exit 2
	fi
    else
	model="$applyModel"
    fi
    java -Djava.io.tmpdir=$TMPDIR weka.filters.supervised.attribute.AddClassification -serialized "$model" -classification -remove-old-class -i "$testArff" -o "$outputArff" -c last  2> >(grep -v "Picked up _JAVA_OPTIONS:" | grep -v "llegal reflective" | grep -v "illegal access operations will be denied" | grep -v "Please consider reporting this" | grep -v "com.github.fommil.netlib")
    status=$?
    if [ $status -ne 0 ]; then
	echo "$progName,$LINENO: weka testing returned an error, aborting. testArff=$testArff" 1>&2
	exit 4
    fi
    if [ ! -s "$outputArff" ]; then
	echo "$progName,$LINENO: weka testing did not generate output predictions '$outputArff', aborting. testArff=$testArff" 1>&2
	exit 5
    fi
    if [ -z "$saveModel" ] && [ -z "$applyModel" ]; then
	rm -f "$model"
    fi
}


while getopts 'a:hp:m:k:' option ; do
    case $option in
	"h" ) usage
	      exit 0;;
	"a" ) applyModel=$OPTARG;;
	"k" ) wekaStdOut=$OPTARG;;
	"p" ) extraParams=$OPTARG;;
	"m" ) saveModel=$OPTARG;;
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
wekaClass="$1"
trainArff="$2"
testArff="$3"
outputArff="$4"

if [ -z "$extraParams" ]; then
    trainAndApply "$trainArff" "$testArff" "$outputArff" "$wekaClass"
else
    trainAndApply "$trainArff" "$testArff" "$outputArff" "$wekaClass" "$extraParams"
fi

