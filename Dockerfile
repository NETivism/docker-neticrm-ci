FROM netivism/docker-debian-php:7.4
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

### develop tools
ENV \
  PATH=$PATH:/root/phpunit \
  PHANTOMJS_VERSION=1.9.8

#xdebug
RUN \
  mkdir -p /var/www/html/log/xdebug && chown -R www-data:www-data /var/www/html/log/xdebug && \
  apt-get update && \
  apt-get install -y php7.4-cgi net-tools && \
  pecl install xdebug-3.1.6 && \
  bash -c "echo zend_extension=xdebug.so > /etc/php/7.4/mods-available/xdebug.ini" && \
  bash -c "phpenmod xdebug" && \
  cp -f /home/docker/php/develop.ini /etc/php/7.4/fpm/conf.d/x-develop.ini

#phpunit
RUN \
  mkdir -p /root/phpunit/extensions && \
  wget -O /root/phpunit/phpunit https://phar.phpunit.de/phpunit-7.phar && \
  chmod +x /root/phpunit/phpunit && \
  wget -O /root/phpunit/extensions/dbunit.phar https://phar.phpunit.de/dbunit.phar && \
  chmod +x /root/phpunit/extensions/dbunit.phar && \
  cp /home/docker/php/phpunit.xml /root/phpunit/ && \
  echo "alias phpunit='phpunit -c ~/phpunit/phpunit.xml'" > /root/.bashrc

#casperjs
RUN \
  apt-get install -y libfreetype6 libfontconfig bzip2 python && \
  mkdir -p /srv/var && \
  wget --no-check-certificate -O /tmp/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 && \
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
  apt-get remove -y php7.4-dev gcc make autoconf libc-dev pkg-config php-pear && \
  apt-get autoremove -y && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

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

### ci tools
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

# we don't have mysql setup on vanilla image
ADD container/my.cnf /etc/mysql/my.cnf

# override supervisord to prevent conflict
ADD container/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# add initial script
ADD container/init.sh /init.sh

WORKDIR /mnt/neticrm-7/civicrm
CMD ["/usr/bin/supervisord"]
