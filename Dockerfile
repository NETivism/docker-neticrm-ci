FROM netivism/docker-wheezy-php55:fpm
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

ENV \
  COMPOSER_HOME=/root/.composer \
  PATH=/root/phpunit:/root/.composer/vendor/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  PHANTOMJS_VERSION=1.9.8

# composer
RUN \
  apt-get update && \
  apt-get install -y \
    net-tools \
    php5.6-cgi \
    gawk

#phpunit
RUN \
  mkdir -p /root/phpunit/extensions && \
  wget -O /root/phpunit/phpunit https://phar.phpunit.de/phpunit-5.phar && \
  chmod +x /root/phpunit/phpunit && \
  cp /home/docker/php/phpunit.xml /root/phpunit/ && \
  echo "alias phpunit='phpunit -c ~/phpunit/phpunit.xml'" > /root/.bashrc

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

# npm / nodejs
RUN \
  cd /tmp && \
  curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && \
  apt-get install -y nodejs && \
  curl https://www.npmjs.com/install.sh | sh && \
  node -v && npm -v

# playwright
RUN \
  sed -i 's/main$/main contrib non-free/g' /etc/apt/sources.list && apt-get update && \
  mkdir -p /tmp/playwright && cd /tmp/playwright && \
  npm install -g -D @playwright/test && \
  npx playwright install --with-deps chromium

### drupal download
COPY container/drupal-download.sh /tmp
COPY container/drupalmodule-download.sh /tmp
RUN \
  chmod +x /tmp/drupal-download.sh && \
  chmod +x /tmp/drupalmodule-download.sh

RUN \
  /tmp/drupal-download.sh 7 && \
  mkdir -p /var/www/html/sites/all/modules && \
  /tmp/drupalmodule-download.sh 7 && \
  mkdir -p /var/www/html/log/supervisor && \
  mkdir -p /mnt/neticrm-7/civicrm

ADD container/my.cnf /etc/mysql/mariadb.cnf
ADD container/mysql-init.sh /usr/local/bin/mysql-init.sh
ADD container/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ADD container/init-7.sh /init.sh

WORKDIR /mnt/neticrm-7/civicrm
CMD ["/usr/bin/supervisord"]
