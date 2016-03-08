#!/bin/bash

# weka.jar (and any other java libs) must be in CLASSPATH

javaMem="1024m"

if [ $# -ne 4 ]; then
  echo "Syntax: $0 <classifer class and options> <test set (arff)> <model input filename> <prediction output filename>" 1>&2
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
