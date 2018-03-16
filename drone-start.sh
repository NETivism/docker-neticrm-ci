#!/bin/bash

# check drone started
EXISTS=`docker ps -q -f name=drone`
REALPATH=`realpath $0`
WORKDIR=`dirname $REALPATH`

if [ -f "./drone/env" ]; then
  source ./drone/env
else
  echo "No environmental file in drone/env"
  exit 1
fi

if [ -z "$EXISTS" ]; then
  cd $WORKDIR
  docker-compose up -d
fi;
