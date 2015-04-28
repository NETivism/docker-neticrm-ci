WORKDIR=`pwd`
docker stop neticrm-ci
docker rm neticrm-ci
docker run -d --name neticrm-ci \
  -p 8888:8888 \
  -v /etc/localtime:/etc/localtime:ro \
  -v $WORKDIR/init.sh:/init.sh \
  -e "TZ=Asia/Taipei" \
  -i -t netivism/neticrm-ci /init.sh
