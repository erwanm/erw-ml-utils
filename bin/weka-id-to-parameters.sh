#!/bin/bash
# EM April 14
# TODO

progName="weka-id-to-parameters.sh"
id="$1"

if [ -z "$id" ]; then
    echo "$progName: usage: $progName <weka id>" 1>&2
    exit 1
fi
if [[ $id == M5P-M* ]]; then  # M5P-M4
    m=${id#M5P-M}
    param="weka.classifiers.trees.M5P -M $m" 
    if [[ $id == M5P-M*-R ]]; then  # M5P-M4-R
	param="$param -R"
    fi
elif  [[ $id == SMO-C*-N* ]]; then # SMO-C1-N0
    c0=${id#SMO-C}
    c=${c0%%-*}
    n0=${c0#*-N}
    n=${n0%%-*}
    param="weka.classifiers.functions.SMOreg -C $c -N $n"
    if [[ $id == *RBF ]]; then # SMO-C2-N0-RBF
	param="$param -K weka.classifiers.functions.supportVector.RBFKernel"
    elif [[ $id == *NormPoly ]]; then SMO-C1-N0-NormPoly
 	param="$param -K weka.classifiers.functions.supportVector.NormalizedPolyKernel"
    fi
elif [[ $id == J48-M* ]]; then  # M5P-M2
    m=${id#J48-M}
    param="weka.classifiers.trees.J48 -M $m" 
elif [[ $id == LogRegRidge ]]; then  # 
    param="weka.classifiers.functions.Logistic" 
elif [[ $id == LogRegBoost ]]; then  # 
    param="weka.classifiers.functions.SimpleLogistic -S" # -S supposedly prevent (internal) cross-validation, which crashes if not enough instances
elif [[ $id == LinearReg ]]; then  # 
    param="weka.classifiers.functions.LinearRegression" 
elif [[ $id == SMO ]]; then  # 
    param="weka.classifiers.functions.SMOreg" 
else
    echo "$progName: invalid id '$id'" 1>&2
    exit 2
fi
echo "$param"
exit 0

# TODO:
#SMO-C1-N0-T0.0001	"weka.classifiers.functions.SMOreg -C 1 -N 0 -I "	"weka.classifiers.functions.supportVector.RegSMOImproved -T 0.0001"
#SMO-C1-N0-T0.01	"weka.classifiers.functions.SMOreg -C 1 -N 0 -I "	"weka.classifiers.functions.supportVector.RegSMOImproved -T 0.01"
#SMO-C2-RBF-N0-V	"weka.classifiers.functions.SMOreg -C 2 -N 0 -K weka.classifiers.functions.supportVector.RBFKernel -I "	"weka.classifiers.functions.supportVector.RegSMOImproved -V"
#Pace	"weka.classifiers.functions.PaceRegression"
