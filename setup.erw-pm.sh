#!/bin/bash
# EM March 16
#
# Requires erw-bash-commons to have been activated
# This script must be sourced from the directory where it is located
#

addToEnvVar "$(pwd)/bin" PATH :
erw-pm activate erw-bash-commons
erw-pm activate weka
