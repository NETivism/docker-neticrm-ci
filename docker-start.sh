WORKDIR=`pwd`

echo "Remove exists containder neticrm-ci ..."
docker stop neticrm-ci
docker rm neticrm-ci

echo "Updating repository netivism/neticrm-ci"
sleep 3s
docker pull netivism/neticrm-ci:7.x
docker run -dit --rm \
  --name neticrm-ci \
  -p 8888:80 \
  -v /etc/localtime:/etc/localtime:ro \
  -v $WORKDIR/init.sh:/init.sh \
  -e "TZ=Asia/Taipei" \
  -e "RUNPORT=80" \
  netivism/neticrm-ci:7.x

echo "display logs..."
docker logs -f neticrm-ci
