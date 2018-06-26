#!/bin/bash

#source lib-mwe.sh
source common-lib.sh
source file-lib.sh


set -e

progName=$(basename "$BASH_SOURCE")

force=0
paramPrefix=""
writeTemplateFile=""
verbose=""

function usage {
  echo
  echo "Usage: $progName [options] <config file> <training file> <model file>"
  echo
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -f force recomputing features even if model already there."
  echo "    -p <prefix> parameter names prefixed with this in the config file."
  echo "    -t <template file> write template here instead of using a temporary"
  echo "       file."
  echo "    -v verbose."
  echo
}







OPTIND=1
while getopts 'hfp:t:v' option ; do 
    case $option in
	"h" ) usage
 	      exit 0;;
	"f" ) force=1;;
	"p" ) paramPrefix="$OPTARG";;
	"t" ) writeTemplateFile="$OPTARG";;
	"v" ) verbose="yep";;
 	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 3 ]; then
    echo "Error: expecting 3 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi


configFile="$1"
trainFile="$2"
modelFile="$3"

dieIfNoSuchFile "$configFile" "$progName: "
dieIfNoSuchFile "$trainFile" "$progName: "

# step 1 : generate template file

columnsArgs=$(grep "^${paramPrefix}col." "$configFile" | sed "s/^${paramPrefix}col.//g" | tr '=' ':' | tr '\n' ' ')
readFromParamFile "$configFile" "${paramPrefix}pattern.singleNGramSize" "$progName: " "" "" "" singleSizeOpt

patOpts=""
if [ $singleSizeOpt -ne 0 ]; then
    patOpts="$patOpts -s"
fi
if [ -z "$writeTemplateFile" ]; then
    templateFile=$(mktemp --tmpdir "tmp.$progName.template.XXXXXXXXXX")
else
    templateFile="$writeTemplateFile"
fi
comm="crf-cumulative-pattern.pl $patOpts -o $templateFile $columnsArgs"
eval "$comm" || exit $?


# step 2: train the model

readFromParamFile "$configFile" "${paramPrefix}crftool" "$progName: " "" "" "" crfTool

if [ "$crfTool" == "crf++" ]; then
    readFromParamFile "$configFile" "${paramPrefix}crfpp.cost" "$progName: " "" "" "" crfppCost
    readFromParamFile "$configFile" "${paramPrefix}crfpp.minfreq" "$progName: " "" "" "" crfppMinfreq
    readFromParamFile "$configFile" "${paramPrefix}crfpp.algo" "$progName: " "" "" "" crfppAlgo
    trainOpts="-f $crfppMinfreq -c $crfppCost -a $crfppAlgo"
    comm="crf_learn $trainOpts $templateFile $trainFile $modelFile"
elif [ "$crfTool" == "wapiti" ]; then
    readFromParamFile "$configFile" "${paramPrefix}wapiti.algo" "$progName: " "" "" "" wapitiAlgo
    readFromParamFile "$configFile" "${paramPrefix}wapiti.sparse" "$progName: " "" "" "" wapitiSparse
    trainOpts="-a $wapitiAlgo"
    if [ $wapitiSparse -ne 0 ]; then
	trainOpts="$trainOpts -s"
    fi
    comm="wapiti train $trainOpts -p $templateFile $trainFile $modelFile"
else
    echo "Error: invalid value for parameter 'crfTool': '$crfTool'" 1>&2
fi
if [ -z "$verbose" ]; then
    comm="$comm >/dev/null"
fi
#echo "DEBUG: '$comm'" 1>&2
stderrFile=$(mktemp --tmpdir "tmp.$progName.stderr.XXXXXXXXXX")
eval "$comm 2>$stderrFile"
if [ $? -ne 0 ]; then
    cat $stderrFile 1>&2
    exit 3
fi

rm -f $stderrFile
if [ -z "$writeTemplateFile" ]; then
    rm -f $templateFile
fi
