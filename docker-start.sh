#!/bin/bash
WORKDIR=`pwd`

docker rm -f neticrm-ci-php7
docker run -d \
  --name neticrm-ci-php7 \
  -p 8888:8080 \
  -v /etc/localtime:/etc/localtime:ro \
  -v $WORKDIR/container/init.sh:/init.sh \
  -v /mnt/neticrm-7/civicrm:/mnt/neticrm-7/civicrm \
  -e "TZ=Asia/Taipei" \
  -e "RUNPORT=8080" \
  -e "DRUPAL_ROOT=/var/www/html" \
  -e "CIVICRM_TEST_DSN=mysql://root@localhost/neticrmci" \
  netivism/neticrm-ci:drone-php7
docker exec neticrm-ci-php7 /init.sh
