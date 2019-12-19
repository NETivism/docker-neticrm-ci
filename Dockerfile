FROM netivism/docker-debian-php:develop
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

RUN \
  wget -q --no-check-certificate -O /tmp/drupal.tar.gz https://ftp.drupal.org/files/projects/drupal-7.69.tar.gz && \
  tar -zxf /tmp/drupal.tar.gz -C /tmp && \
  mv /tmp/drupal-7.69/* /var/www/html && \
  mkdir -p /var/www/html/sites/all/modules && \
  mkdir -p /var/www/html/log/supervisor

RUN \
  mkdir -p /mnt/neticrm-7/civicrm && \
  wget -q --no-check-certificate -O /tmp/transliteration.tar.gz https://ftp.drupal.org/files/projects/transliteration-7.x-3.2.tar.gz && \
  tar -zxf /tmp/transliteration.tar.gz -C /var/www/html/sites/all/modules/ && \
  wget -q --no-check-certificate -O /tmp/simpletest.tar.gz https://ftp.drupal.org/files/projects/simpletest-7.x-2.0.tar.gz && \
  tar -zxf /tmp/simpletest.tar.gz -C /var/www/html/sites/all/modules/

ADD container/init.sh /init.sh
ADD container/my.cnf /etc/mysql/my.cnf
ADD container/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD container/ansi2html.sh /usr/local/bin/ansi2html
ADD container/mysql-init.sh /usr/local/bin/mysql-init.sh

WORKDIR /mnt/neticrm-7/civicrm
CMD ["/usr/bin/supervisord"]
