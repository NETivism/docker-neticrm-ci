#!/bin/bash
WORKDIR=`pwd`

echo "Updating repository netivism/neticrm-ci"
docker run -d \
  --name neticrm-ci \
  -p 8888:80 \
  -v /etc/localtime:/etc/localtime:ro \
  -v $WORKDIR/init.sh:/init.sh \
  -e "TZ=Asia/Taipei" \
  -e "RUNPORT=80" \
  netivism/neticrm-ci:7.x
