FROM netivism/docker-wheezy-php55:fpm
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

ENV \
  COMPOSER_HOME=/root/.composer \
  PATH=/root/.composer/vendor/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  PHANTOMJS_VERSION=1.9.7

# composer
RUN \
  apt-get update && \
  apt-get install -y \
    net-tools \
    php5.6-cgi \
    gawk

RUN \
  composer global require drush/drush:8.3.0 && \
  composer global require phpunit/phpunit:^5 && \
  composer global require phpunit/dbunit && \
  cd /root/.composer && \
  composer clearcache

# casperjs
RUN \
  apt-get install -y libfreetype6 libfontconfig bzip2 python && \
  mkdir -p /srv/var && \
  wget -q --no-check-certificate -O /tmp/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 && \
  tar -xjf /tmp/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 -C /tmp && \
  rm -f /tmp/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 && \
  mv /tmp/phantomjs-$PHANTOMJS_VERSION-linux-x86_64/ /srv/var/phantomjs && \
  ln -s /srv/var/phantomjs/bin/phantomjs /usr/bin/phantomjs && \
  git clone https://github.com/n1k0/casperjs.git /srv/var/casperjs && \
  ln -s /srv/var/casperjs/bin/casperjs /usr/bin/casperjs && \
  apt-get autoremove -y && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN \
  wget -q --no-check-certificate -O /tmp/drupal.tar.gz https://ftp.drupal.org/files/projects/drupal-7.84.tar.gz && \
  tar -zxf /tmp/drupal.tar.gz -C /tmp && \
  mv /tmp/drupal-7.84/* /var/www/html && \
  mkdir -p /var/www/html/sites/all/modules && \
  mkdir -p /var/www/html/log/supervisor

RUN \
  mkdir -p /mnt/neticrm-7/civicrm && \
  wget -q --no-check-certificate -O /tmp/transliteration.tar.gz https://ftp.drupal.org/files/projects/transliteration-7.x-3.2.tar.gz && \
  tar -zxf /tmp/transliteration.tar.gz -C /var/www/html/sites/all/modules/ && \
  wget -q --no-check-certificate -O /tmp/simpletest.tar.gz https://ftp.drupal.org/files/projects/simpletest-7.x-2.0.tar.gz && \
  tar -zxf /tmp/simpletest.tar.gz -C /var/www/html/sites/all/modules/

ADD container/init.sh /init.sh
ADD container/my.cnf /etc/mysql/mariadb.cnf
ADD container/mysql-init.sh /usr/local/bin/mysql-init.sh
ADD container/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /mnt/neticrm-7/civicrm
CMD ["/usr/bin/supervisord"]
