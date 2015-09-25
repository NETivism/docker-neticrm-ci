#!/bin/bash
if [ "$#" -ne 2 ]; then
  echo "  $0 drupal-version neticrm-version"
  echo "  $0 7.38 2.0-dev"
  exit
fi
WORKDIR=`pwd`

docker rm -f neticrm-ci
docker run -d \
  --name neticrm-ci \
  -p 8888:80 \
  -v /etc/localtime:/etc/localtime:ro \
  -v $WORKDIR/container/init.sh:/init.sh \
  -e "TZ=Asia/Taipei" \
  -e "RUNPORT=80" \
  -e "DRUPAL_ROOT=/var/www/html" \
  -e "CIVICRM_TEST_DSN=mysql://root@127.0.0.1/neticrmci" \
  -e "DRUPAL=$1" \
  -e "NETICRM=$2" \
  netivism/neticrm-ci
