#!/bin/bash
if [ -z "$1" ]; then
  echo 'Usage:'
  echo "  $0 ip:port"
  echo 'Example: for only allow localhost (recommended)'
  echo "  $0 127.0.0.1:8888"
  echo 'Example: this will expose your port (use carefully)'
  echo "  $0 0.0.0.0:8888"
  exit 1
fi
WORKDIR=`pwd`

docker rm -f neticrm-ci-php5
docker run -d \
  --name neticrm-ci-php5 \
  -p $1:8080 \
  -v /etc/localtime:/etc/localtime:ro \
  -v $WORKDIR/container/init.sh:/init.sh \
  -v /mnt/neticrm-7/civicrm:/mnt/neticrm-7/civicrm \
  -e "TZ=Asia/Taipei" \
  -e "RUNPORT=8080" \
  -e "DRUPAL_ROOT=/var/www/html" \
  -e "CIVICRM_TEST_DSN=mysqli://root@localhost/neticrmci" \
  netivism/neticrm-ci:drone-php5
docker exec neticrm-ci-php5 /init.sh
