#!/bin/bash
if [ "$#" -ne 2 ]; then
  echo "  $0 drupal-version neticrm-version"
  echo "  $0 7.37 2.0-dev"
  exit
fi
WORKDIR=`pwd`

echo "Updating repository netivism/neticrm-ci"
docker run -d \
  --name neticrm-ci \
  -p 8888:80 \
  -v /etc/localtime:/etc/localtime:ro \
  -v $WORKDIR/init.sh:/init.sh \
  -e "TZ=Asia/Taipei" \
  -e "RUNPORT=80" \
  -e "DRUPAL=$1" \
  -e "NETICRM=$2" \
  netivism/neticrm-ci
