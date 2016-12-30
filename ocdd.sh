#!/bin/bash
source ./functions.sh

source ocdd.conf


if [ "$1" == "initialize" ] ; then
  initializeOCDD
  exit 0
fi

########### START - System variables  #######################

DB_FILE=db.txt
CURL_COMMAND="curl -s --unix-socket ${DOCKER_SOCKET} ${DOCKER_API_URL}"

########### END - System variables  #######################


buildDBWithContainerNamesAndIPs  "${CURL_COMMAND}" ${DB_FILE}

readDBFile ${DB_FILE}
