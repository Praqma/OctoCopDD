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

source ./ocdd.conf


JQ=$(which jq)
if [ "$JQ" == "" ] ; then
  echo "jq was not found. Please install before continuing. Exiting ..."
  safe_exit 1
fi


if [ "$1" == "initialize" ] ; then
  initializeOCDD
  
  # after OCDD files / iptables are initialized , stop and start the OCDD docker-compose app to start DNS service.

  echo "- Stopping OCDD compose app (DNS, C-Advisor) ..."
  docker-compose stop

  echo
  echo "- Starting OCDD compose app (DNS, C-Advisor). This may take few minutes when run for the first time..."
  docker-compose up -d

  sleep 2

  echo
  echo "You can now run ./ocdd.sh without any parameters , so it could detect any running containers and does it's thing!"
  safe_exit 0
fi





########### START - System variables  #######################

DB_FILE=db.txt
CURL_COMMAND="curl -s --unix-socket ${DOCKER_SOCKET} ${DOCKER_API_URL}"

########### END - System variables  #######################


buildDBWithContainerNamesAndIPs  "${CURL_COMMAND}" ${DB_FILE}

readDBFile ${DB_FILE}


# The sleep allows the DNS service to start up before we query it.
sleep 2

echo
echo "-------------------------------------------------------------------------------------"
echo
echo "Here is how various hostnames and their IPs look like (in DNS) ${TOOLBOX_SUBDOMAIN_NAME} :"
echo
dig axfr  +onesoa ${TOOLBOX_SUBDOMAIN_NAME}  @127.0.0.1 | grep -w A
echo

safe_exit 0
