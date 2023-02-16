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

CONTAINER_NAME=neticrm-ci-php8
TAG_NAME=drone-php8
DRUPAL_VERSION=7

WORKDIR=`pwd`
if [ -d $HOME/mnt/neticrm-7/civicrm ];then
  MOUNT=$HOME/mnt/neticrm-7/civicrm
else
  MOUNT=/mnt/neticrm-7/civicrm
fi

# always fetch latest image
docker pull ghcr.io/netivism/docker-neticrm-ci:$TAG_NAME

# purge previous container
EXISTS_CONTAINER=$(docker ps -q -f "name=$CONTAINER_NAME")
if [ -n $EXISTS_CONTAINER ]; then
  docker rm -f $CONTAINER_NAME
  echo "Remove old container $CONTAINER_NAME successfully"
fi

# purge previous images
OLD_IMAGE=$(docker images ghcr.io/netivism/docker-neticrm-ci --filter "dangling=true" -q)
if [ -n "$OLD_IMAGE" ]; then
  docker rmi $(docker images ghcr.io/netivism/docker-neticrm-ci --filter "dangling=true" -q)
fi

# start container
docker run -d \
  --name $CONTAINER_NAME \
  -p $1:8080 \
  -v /etc/localtime:/etc/localtime:ro \
  -v $WORKDIR/container/init-$DRUPAL_VERSION.sh:/init.sh \
  -v $MOUNT:/mnt/neticrm-7/civicrm \
  -e "TZ=Asia/Taipei" \
  -e "RUNPORT=8080" \
  -e "DRUPAL_ROOT=/var/www/html" \
  -e "CIVICRM_TEST_DSN=mysqli://root@localhost/neticrmci" \
  -e "DRUPAL=$DRUPAL_VERSION" \
  ghcr.io/netivism/docker-neticrm-ci:$TAG_NAME

# install drupal
docker exec $CONTAINER_NAME /init.sh
