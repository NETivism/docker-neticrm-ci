FROM netivism/docker-debian-php:develop
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

WORKDIR /mnt/neticrm-7/civicrm
CMD ["/usr/bin/supervisord"]
