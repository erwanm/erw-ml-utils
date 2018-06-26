#!/bin/bash

#source lib-mwe.sh
source common-lib.sh
source file-lib.sh



progName=$(basename "$BASH_SOURCE")

force=0
paramPrefix=""
verbose=""
nbest=""
addProbCol=""

function usage {
  echo
  echo "Usage: $progName [options] <config file> <model file> <input test file> <output file>"
  echo
  echo "  Applies a CRF model <model file> to <input test file> according to the"
  echo "  parameters defined in <config file>, and writes the resulting predictions"
  echo "  to <output file> (original columns + new one containing predicted labels)."
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -f force recomputing even if output already there."
  echo "    -p <prefix> parameter names prefixed with this in the config file."
  echo "    -n <N> output the N best sequences of labels instead of only the most"
  echo "       likely one (remark: if there are not enough possible sequences,"
  echo "       crf++ stops before N; Wapiti gives meaningless sequences)."
  echo "    -s provide the probability of the most likely label as an additional"
  echo "       column (format: '<label>/<probability>')."
  echo "    -v verbose (remark: no output from crf++ in testing mode)."
  echo
}







OPTIND=1
while getopts 'hp:n:sv' option ; do 
    case $option in
	"h" ) usage
 	      exit 0;;
	"f" ) force=1;;
	"p" ) paramPrefix="$OPTARG";;
	"n" ) nbest="$OPTARG";;
	"s" ) addProbCol="yep";;
	"v" ) verbose="yep";;
 	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 4 ]; then
    echo "Error: expecting 4 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi


configFile="$1"
modelFile="$2"
testFile="$3"
outputFile="$4"

dieIfNoSuchFile "$configFile" "$progName: "
dieIfNoSuchFile "$modelFile" "$progName: "
dieIfNoSuchFile "$testFile" "$progName: "



# step 2: train the model

readFromParamFile "$configFile" "${paramPrefix}crftool" "$progName: " "" "" "" crfTool

testOpts="-m \"$modelFile\""
if [ ! -z "$nbest" ]; then
    testOpts="$testOpts -n $nbest"
fi
if [ "$crfTool" == "crf++" ]; then
    if [ ! -z "$addProbCol" ]; then
	testOpts="$testOpts -v1" 
    fi
    comm="crf_test $testOpts -o \"$outputFile\" \"$testFile\""
elif [ "$crfTool" == "wapiti" ]; then
    if [ ! -z "$addProbCol" ]; then
	testOpts="$testOpts -s" 
    fi
    comm="wapiti label -p $testOpts  \"$testFile\" \"$outputFile\""
else
    echo "Error: invalid value for parameter 'crfTool': '$crfTool'" 1>&2
fi

stderrFile=$(mktemp --tmpdir "tmp.$progName.stderr.XXXXXXXXXX")
if [ -z "$verbose" ]; then
    comm="$comm  2>$stderrFile >/dev/null"
fi

#echo "DEBUG: '$comm'" 1>&2
eval "$comm"
if [ $? -ne 0 ] || grep -q -i error $stderrFile; then
    if [ -z "$verbose" ]; then
        cat $stderrFile 1>&2
	rm -f $stderrFile
    fi
    exit 3
fi
eval "$comm"

rm -f $stderrFile
