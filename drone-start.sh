#!/bin/bash

# check drone started
EXISTS=`docker ps -q -f name=drone`
REALPATH=`realpath $0`
WORKDIR=`dirname $REALPATH`

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Usage:"
  echo "  $0 github_client_id github_secret organization"
  exit 1;
fi

if [ -z "$EXISTS" ]; then
  export DRONE_GITHUB_CLIENT=$1
  export DRONE_GITHUB_SECRET=$2
  export DRONE_ORGS=$3
  export DRONE_SECRET=NETivism
  cd $WORKDIR
  docker-compose up -d
fi;
