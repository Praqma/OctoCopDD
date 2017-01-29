#!/bin/bash

SCRIPT_PATH=$(dirname $0)
pushd $(pwd) > /dev/null
cd $SCRIPT_PATH


function safe_exit() {
  # need to popd everytime I use 'exit N' , so I made a small function, which will do two things.
  # popd and exit with the error code received by this function.
  popd > /dev/null
  echo
  exit $1
}


source ./functions.sh

source ocdd.conf


JQ=$(which jq)
if [ "$JQ" == "" ] ; then
  echo "jq was not found. Please install before continuing. Exiting ..."
  safe_exit 1
fi


if [ "$1" == "initialize" ] ; then
  initializeOCDD
  safe_exit 0
fi





########### START - System variables  #######################

DB_FILE=db.txt
CURL_COMMAND="curl -s --unix-socket ${DOCKER_SOCKET} ${DOCKER_API_URL}"

########### END - System variables  #######################


buildDBWithContainerNamesAndIPs  "${CURL_COMMAND}" ${DB_FILE}

readDBFile ${DB_FILE}

safe_exit 0
