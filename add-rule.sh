#!/bin/bash
CIP=$1
CNAME=$2
sudo iptables -t nat -A DOCKER ! -i docker0  \
  -m comment --comment "PRAQMA-${CNAME}" \
  -j DNAT --to-destination $CIP

