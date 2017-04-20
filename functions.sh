#!/bin/bash
source ./ocdd.conf


function initializeOCDD() {
  echo "Initializing OCDD ..."
  rm -f db*.txt iplist*
  cat dns/toolbox.example.com.zone | sudo tee ${DNS_ZONE_FILE} > /dev/null
  
  echo "- Building fresh iplist.txt"
  for IP in $(seq  ${IP_RANGE_START}  ${IP_RANGE_END}); do
    echo "${IP_SUBNET}.${IP}" >> iplist.txt
  done

  echo "- Removing OCDD specific iptables rules ..."
  deleteOCDDiptablesRules

  echo "- Removing additional IP addresses from the network interface - ${NETWORK_DEVICE} ..."
  deleteIPAddresses
}




function readDBFile() {
  local DB_FILE=$1

  local ORIG_IFS=$IFS
  echo

  if [ $DEBUG -eq 1 ] ; then

    echo "For now, we remove all IP addresses from ${NETWORK_DEVICE} interface."
  fi 

  deleteIPAddresses

  # for i in  $(sudo ip addr show dev ${NETWORK_DEVICE}| grep -w inet | grep "/32" | awk '{print $2}' ); do 
  #   sudo ip addr delete ${i} dev ${NETWORK_DEVICE}
  # done

  if [ $DEBUG -eq 1 ] ; then
    echo "Also, empty iptables rules"
  fi

  deleteOCDDiptablesRules

  # Load the number of IPs from the iplist.txt, based on the number of lines in db.txt

  CONTAINER_COUNT=$(grep -v ^$ ${DB_FILE} | wc -l)

  if [ ${CONTAINER_COUNT} -eq 0 ] ; then 
    echo "No containers found in ${DB_FILE} ! Exiting ..."
    safe_exit 1
  else
    echo "CONTAINER_COUNT on this docker host is ${CONTAINER_COUNT} ."
  fi

  echo 

  PUBLIC_IPS_SUBSET_FILE=$(mktemp --suffix=ocdd)

  head -${CONTAINER_COUNT} iplist.txt > ${PUBLIC_IPS_SUBSET_FILE}

  CONTAINERS_PVT_AND_PUB_IPS_FILE=$(mktemp --suffix=ocdd)
  paste -d ' ' ${DB_FILE} ${PUBLIC_IPS_SUBSET_FILE} > ${CONTAINERS_PVT_AND_PUB_IPS_FILE}

  # Remove all previously added entries from DNS_ZONE_FILE 
  sed -i '/ADDED-BY-OCDD-SCRIPT/d' ${DNS_ZONE_FILE}

  # Remove all OCDD's previously generated IPTables rules:
  deleteOCDDiptablesRules

  if [ $DEBUG -eq 1 ] ; then
    echo "Reading file with containers private and public IPs:"
    echo "----------------------------------------------------"
  fi

  echo
  echo "Generating iptables rules and DNS entries for each container..."
  echo
  while read -r LINE ; do
    if [ ! -z "$LINE" ] ; then 
      if [ $DEBUG -eq 1 ] ; then

        echo "Data Record: $LINE"
      fi

      # displayFields "$LINE"
      addDNSEntry "$LINE"

      generateIPTablesRules "$LINE"

      if [ $DEBUG -eq 1 ] ; then
        echo "============================================================================"
      fi
    fi
  done < "${CONTAINERS_PVT_AND_PUB_IPS_FILE}"

  # By this time DNS zone file is rebuilt, so it is better to restart the dns service container.
  # Assuming there is a container named dns in the docker-compose file.
  echo
  docker-compose restart dns

  local IFS=$ORIG_IFS

}

function displayFields() {
  RECORD="$1"
  FS=' '

  if [ $DEBUG -eq 1 ] ; then

    echo "Received: $RECORD"
  fi

  read CNAME CIP PUBLICIP <<< $(echo $RECORD | awk -F "${FS}" '{print $1, $2, $3}')

  if [ $DEBUG -eq 1 ] ; then

    echo "CNAME: $CNAME  - CIP: $CIP - PUBLICIP: $PUBLICIP"
  fi
}


function generateIPTablesRules() {
  RECORD="$1"
  FS=' '

  if [ $DEBUG -eq 1 ] ; then

    echo "Received: $RECORD"
  fi
  read CNAME CIP PUBLICIP <<< $(echo $RECORD | awk -F "${FS}" '{print $1, $2, $3}')

  if [ $DEBUG -eq 1 ] ; then
    echo "Generating IPTables rules for:   CNAME: $CNAME  - CIP: $CIP - PUBLICIP: $PUBLICIP"

    echo "Executing: sudo iptables -t nat -A DOCKER -d ${PUBLICIP} ! -i docker0 \
           -m comment --comment "OCDD-${CNAME}" \
           -j DNAT --to-destination ${CIP}"
  fi

  sudo iptables -t nat -A DOCKER -d ${PUBLICIP} ! -i docker0 \
           -m comment --comment "OCDD-${CNAME}" \
           -j DNAT --to-destination ${CIP}

  # This is the point where we should call some DNS routine to add this PUBLIC IP in DNS zone.
  # What that call should look like is not known yet.

  if [ $DEBUG -eq 1 ] ; then
    echo "Adding this PUBLICIP ${PUBLICIP} to the ${NETWORK_DEVICE} interface. using /32."
  fi
  sudo ip addr add ${PUBLICIP}/32 dev ${NETWORK_DEVICE}
}




function buildDBWithContainerNamesAndIPs() {
  local CURL_COMMAND="$1"
  # local DOCKER_API_URL=$2
  local DB_FILE=$2

  # local CURL_COMMAND="curl -s --unix-socket ${DOCKER_SOCKET} ${DOCKER_API_URL}"

  # The following works for created through both plain docker and docker-compose. Gives name and IP address of containers.
  ##  ${CURL_COMMAND} | jq -r '.[] | .Names[0] + " " + .NetworkSettings.Networks[].IPAddress' > ${DB_FILE}

  # The following was found with Mike's help.
  ${CURL_COMMAND} | jq -r '.[] |  .Labels."com.docker.compose.service" + " "  + .NetworkSettings.Networks[].IPAddress' > ${DB_FILE}


  echo
  if [ -s ${DB_FILE} ] ; then
    echo "Found containers with following (docker-private) IP addresses:"
    echo
    cat ${DB_FILE}
    return 0
  else
    echo "No containers found!"
    return 9
  fi 
  echo
}


function deleteOCDDiptablesRules() {
  # The best way to remove all OCDD rules from iptables is to do the following:
  sudo iptables-save  | grep OCDD | sed 's/^-A/iptables -t nat -D/' | sudo bash

}

function deleteIPAddresses() {
  for i in  $(sudo ip addr show dev ${NETWORK_DEVICE}| grep -w inet | grep "/32" | awk '{print $2}' ); do
    sudo ip addr delete ${i} dev ${NETWORK_DEVICE}
  done

}

function addDNSEntry() {
  RECORD="$1"
  # DNS_ZONE_FILE is global

  FS=' '

  if [ $DEBUG -eq 1 ] ; then

    echo "Received: $RECORD"
  fi

  read CNAME CIP PUBLICIP <<< $(echo $RECORD | awk -F "${FS}" '{print $1, $2, $3}')

  # Extract service name from the container name:
  SERVICE_NAME=$(echo ${CNAME} | sed 's#^/[a-z]*_\([a-z]*\)_[0-9]$#\1#')

  if [ $DEBUG -eq 1 ] ; then
    echo "SERVICE_NAME: $SERVICE_NAME  - CIP: $CIP - PUBLICIP: $PUBLICIP"
  fi
  ## echo -e "${SERVICE_NAME} \t IN \t A \t ${PUBLICIP} \t ; ADDED-BY-OCDD-SCRIPT" | sudo tee -a ${DNS_ZONE_FILE}
  sudo echo -e "${SERVICE_NAME} \t IN \t A \t ${PUBLICIP} \t ; ADDED-BY-OCDD-SCRIPT"  >>  ${DNS_ZONE_FILE}
  
  # Also add this to the index.html 
  ## echo -e "<br>* - ${SERVICE_NAME}.${TOOLBOX_SUBDOMAIN_NAME}" | tee -a ${WEB_INDEX_FILE}
  sudo echo -e "<br>* - ${SERVICE_NAME}.${TOOLBOX_SUBDOMAIN_NAME}" >> ${WEB_INDEX_FILE}

}

function resetDNSZoneFile() {
  # Using cat instead of copy, because the file is volume mounted in a container. Contents can change, but file pointer cannot. (I think).
  sudo cat dns/toolbox.example.com.zone > ${DNS_ZONE_FILE}
} 
