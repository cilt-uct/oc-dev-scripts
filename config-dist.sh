#! /bin/bash
if [ "$BASH" = "" ] ;then echo "Please run with bash"; exit 1; fi

# If you want to change this file (and you should) copy it to config.sh and make your changes
# there so git ignores your local copy.

# Check to see if we are overriden - but only do it once
if [ -f "config.sh" -a "$1" == "" ]
then
    echo "Taking configuration from local config.sh"
    source config.sh include
    return
    exit
elif [ "$1" == "" ]
then
    echo "Using defaults."
    echo "  If you want to override configuration settings, "
    echo "  copy config-dist.sh to config.sh and edit config.sh"
    echo
fi

# Settings
# --------

# The folder where all the ansible scripts reside and the files folder structure
# probably the same folder as ${PWD}
YML="/folder/where/this/repo/is/"

# The folder where the deploy.cfg file are kept for save keeping 
# they contain production passwords
DEPLOY_CFG_FOLDER="."

FILES=$YML"/files"
CONFIG=$YML"/config"
HOSTS_FOLDER=$YML"/hosts/"
TMP_DIR=$FILES"/tmp"

mkdir -p $TMP_DIR

DIRNAME=$(dirname "$0")
PROGNAME=$(basename "$0")
CURRENT_DIR=${PWD}
