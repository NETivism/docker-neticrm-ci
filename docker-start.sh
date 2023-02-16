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
if [ -d $HOME/mnt/neticrm-7/civicrm ];then
  MOUNT=$HOME/mnt/neticrm-7/civicrm
else
  MOUNT=/mnt/neticrm-7/civicrm
fi

docker rm -f neticrm-ci-php8
docker run -d \
  --name neticrm-ci-php8 \
  -p $1:8080 \
  -v /etc/localtime:/etc/localtime:ro \
  -v $WORKDIR/container/init.sh:/init.sh \
  -v $MOUNT:/mnt/neticrm-7/civicrm \
  -e "TZ=Asia/Taipei" \
  -e "RUNPORT=8080" \
  -e "DRUPAL_ROOT=/var/www/html" \
  -e "CIVICRM_TEST_DSN=mysqli://root@localhost/neticrmci" \
  ghcr.io/netivism/docker-neticrm-ci:drone-php8
docker exec neticrm-ci-php8 /init.sh
