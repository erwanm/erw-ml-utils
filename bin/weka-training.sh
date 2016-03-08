#!/bin/bash

# weka.jar (and any other java libs) must be in CLASSPATH

javaMem="1024m"

if [ $# -ne 3 ]; then
  echo "Syntax: $0 <classifer class and options> <training set (arff)> <model output filename>" 1>&2
  exit 1
fi
classifier="$1"
trainingSet="$2"
outputModel="$3"
echo "** Training on '$trainingSet' using '$classifier', model written to '$outputModel'..."
java -Xms$javaMem -Xmx$javaMem  $classifier -t "$trainingSet" -T "$trainingSet" -d "$outputModel"
echo "** Done"
