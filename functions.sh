#!/bin/bash
source ./ocdd.conf


function initializeOCDD() {
  echo "Initializing OCDD ..."
  rm -f db*.txt iplist*
  cat dns/toolbox.example.com.zone | sudo tee ${DNS_ZONE_FILE} > /dev/null
  
  # Build fresh iplist.txt
  for IP in $(seq  ${IP_RANGE_START}  ${IP_RANGE_END}); do
    echo "${IP_SUBNET}.${IP}" >> iplist.txt
  done

  emptyIPTablesRules

  emptyIPAddresses
}




function readDBFile() {
  local DB_FILE=$1

  local ORIG_IFS=$IFS
  echo

  echo "For now, we remove all IP addresses from ens3 interface. Figure out a better way to do it later."

  emptyIPAddresses

  # for i in  $(sudo ip addr show dev ens3| grep -w inet | grep "/32" | awk '{print $2}' ); do 
  #   sudo ip addr delete ${i} dev ens3
  # done

  echo "Also, empty iptables rules"
  emptyIPTablesRules

  # Load the number of IPs from the iplist.txt, based on the number of lines in db.txt

  CONTAINER_COUNT=$(grep -v ^$ ${DB_FILE} | wc -l)

  if [ ${CONTAINER_COUNT} -eq 0 ] ; then 
    echo "No containers found in ${DB_FILE} ! Exiting ..."
    exit 1
  else
    echo "CONTAINER_COUNT in ${DB_FILE} is ${CONTAINER_COUNT}"
  fi

  PUBLIC_IPS_SUBSET_FILE=$(mktemp --suffix=ocdd)

  head -${CONTAINER_COUNT} iplist.txt > ${PUBLIC_IPS_SUBSET_FILE}

  CONTAINERS_PVT_AND_PUB_IPS_FILE=$(mktemp --suffix=ocdd)
  paste -d ' ' ${DB_FILE} ${PUBLIC_IPS_SUBSET_FILE} > ${CONTAINERS_PVT_AND_PUB_IPS_FILE}


  echo "Reading file with containers private and public IPs:"
  echo "----------------------------------------------------"
  while read -r LINE ; do
    if [ ! -z "$LINE" ] ; then 
      echo "Data Record: $LINE"
      # displayFields "$LINE"
      addDNSEntry "$LINE"

      generateIPTablesRules "$LINE"
      echo "============================================================================"
    fi
  done < "${CONTAINERS_PVT_AND_PUB_IPS_FILE}"

  # By this time DNS zone file is rebuilt, so it is better to restart the dns service container.
  # Assuming there is a container named dns in the docker-compose file.
  docker-compose restart dns

  local IFS=$ORIG_IFS

}

function displayFields() {
  RECORD="$1"
  FS=' '
  echo "Received: $RECORD"
  read CNAME CIP PUBLICIP <<< $(echo $RECORD | awk -F "${FS}" '{print $1, $2, $3}')
  echo "CNAME: $CNAME  - CIP: $CIP - PUBLICIP: $PUBLICIP"
}


function generateIPTablesRules() {
  RECORD="$1"
  FS=' '
  echo "Received: $RECORD"
  read CNAME CIP PUBLICIP <<< $(echo $RECORD | awk -F "${FS}" '{print $1, $2, $3}')

  echo "Generating IPTables rules for:   CNAME: $CNAME  - CIP: $CIP - PUBLICIP: $PUBLICIP"

  echo "Executing: sudo iptables -t nat -A DOCKER -d ${PUBLICIP} ! -i docker0 \
           -m comment --comment "PRAQMA-${CNAME}" \
           -j DNAT --to-destination ${CIP}"

  sudo iptables -t nat -A DOCKER -d ${PUBLICIP} ! -i docker0 \
           -m comment --comment "PRAQMA-${CNAME}" \
           -j DNAT --to-destination ${CIP}

  # This is the point where we should call some DNS routine to add this PUBLIC IP in DNS zone.
  # What that call should look like is not known yet.

  echo "Add this PUBLICIP ${PUBLICIP} to the ens3 interface. using /32."
  sudo ip addr add ${PUBLICIP}/32 dev ens3
}




function buildDBWithContainerNamesAndIPs() {
  local CURL_COMMAND="$1"
  # local DOCKER_API_URL=$2
  local DB_FILE=$2

  # local CURL_COMMAND="curl -s --unix-socket ${DOCKER_SOCKET} ${DOCKER_API_URL}"

  # The following works for created through both plain docker and docker-compose. Gives name and IP address of containers.
  ${CURL_COMMAND} | jq -r '.[] | .Names[0] + " " + .NetworkSettings.Networks[].IPAddress' > ${DB_FILE}

  if [ -s ${DB_FILE} ] ; then
    echo "Found containers with following IP Addresses:"
    cat ${DB_FILE}
    return 0
  else
    echo "No containers found!"
    return 9
  fi 

}


function emptyIPTablesRules() {
  # The best way to remove all PRAQMA rules from iptables is to do the following:
  sudo iptables-save  | grep PRAQMA | sed 's/^-A/iptables -t nat -D/' | sudo bash

}

function emptyIPAddresses() {
  for i in  $(sudo ip addr show dev ens3| grep -w inet | grep "/32" | awk '{print $2}' ); do
    sudo ip addr delete ${i} dev ens3
  done

}

function addDNSEntry() {
  RECORD="$1"
  DNS_ZONE_FILE=/opt/toolbox/dns/toolbox.example.com.zone

  FS=' '
  echo "Received: $RECORD"
  read CNAME CIP PUBLICIP <<< $(echo $RECORD | awk -F "${FS}" '{print $1, $2, $3}')

  # Extract service name from the container name:
  SERVICE_NAME=$(echo ${CNAME} | sed 's#^/[a-z]*_\([a-z]*\)_[0-9]$#\1#')

  echo "SERVICE_NAME: $SERVICE_NAME  - CIP: $CIP - PUBLICIP: $PUBLICIP"
  echo -e "${SERVICE_NAME} \t IN \t A \t ${PUBLICIP} \t ; ADDED-BY-OCDD-SCRIPT" | sudo tee -a ${DNS_ZONE_FILE}
}

function resetDNSZoneFile() {
  # Using cat instead of copy, because the file is volume mounted in a container. Contents can change, but file pointer cannot. (I think).
  sudo cat dns/toolbox.example.com.zone > /opt/toolbox/dns/toolbox.example.com.zone 
} 
