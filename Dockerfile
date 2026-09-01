FROM ghcr.io/netivism/docker-debian-base:trixie
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

ENV \
  COMPOSER_HOME=/root/.composer \
  PATH=/root/.composer/vendor/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# basic packages install
RUN \
    apt-get update && \
    apt-get install -y rsyslog apt-transport-https wget gnupg gcc make autoconf libc-dev pkg-config google-perftools qpdf curl vim git-core supervisor procps

# add PHP sury
WORKDIR /etc/apt/sources.list.d
RUN curl -sSL https://packages.sury.org/php/README.txt | bash

#mariadb
RUN \
    apt-get install -y wget mariadb-server mariadb-backup mariadb-client

# wkhtmltopdf
WORKDIR /tmp
RUN \
  apt-get install -y fonts-droid-fallback fontconfig && \
  wget -nv https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb -O wkhtmltox.deb && \
  apt-get update && \
  apt-get install -y ./wkhtmltox.deb && \
  rm -f wkhtmltox.deb

# php
WORKDIR /
RUN \
  apt-get update && \
  apt-get install -y \
    php8.3 \
    php8.3-curl \
    php8.3-imap \
    php8.3-gd \
    php8.3-mysql \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-memcached \
    php8.3-cli \
    php8.3-fpm \
    php8.3-zip \
    php8.3-bz2 \
    php8.3-ssh2 \
    php8.3-yaml

RUN \
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
  cd /root/.composer && \
  find . | grep .git | xargs rm -rf && \
  composer clearcache

### PHP FPM Config
# remove default enabled site
RUN \
  mkdir -p /var/www/html/log/supervisor && \
  git clone https://github.com/NETivism/docker-sh.git /home/docker && \
  cp -f /home/docker/php/default83.ini /etc/php/8.3/docker_setup.ini && \
  ln -s /etc/php/8.3/docker_setup.ini /etc/php/8.3/fpm/conf.d/ && \
  cp -f /home/docker/php/default83_cli.ini /etc/php/8.3/cli/conf.d/ && \
  cp -f /home/docker/php/default_opcache_blacklist /etc/php/8.3/opcache_blacklist && \
  sed -i 's/^listen = .*/listen = 80/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/^pm = .*/pm = ondemand/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/;daemonize = .*/daemonize = no/g' /etc/php/8.3/fpm/php-fpm.conf && \
  sed -i 's/^pm\.max_children = .*/pm.max_children = 8/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.process_idle_timeout = .*/pm.process_idle_timeout = 15s/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.max_requests = .*/pm.max_requests = 50/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/^;request_terminate_timeout = .*/request_terminate_timeout = 7200/g' /etc/php/8.3/fpm/pool.d/www.conf

RUN \
  mkdir -p /run/php && chmod 777 /run/php

RUN \
  VIMRUNTIME=$(vim --cmd 'echo $VIMRUNTIME' --cmd q 2>&1 | tail -n1) && \
  echo "source $VIMRUNTIME/defaults.vim" > /etc/vim/vimrc.local && \
  echo "let skip_defaults_vim = 1" >> /etc/vim/vimrc.local && \
  echo "if has('mouse')" >> /etc/vim/vimrc.local && \
  echo "  set mouse=" >> /etc/vim/vimrc.local && \
  echo "endif" >> /etc/vim/vimrc.local

### develop tools
ENV \
  PATH=$PATH:/root/phpunit

#phpunit
RUN \
  mkdir -p /root/phpunit/extensions && \
  wget -O /root/phpunit/phpunit https://phar.phpunit.de/phpunit-10.phar && \
  chmod +x /root/phpunit/phpunit && \
  cp /home/docker/php/phpunit.xml /root/phpunit/ && \
  echo "alias phpunit='phpunit -c ~/phpunit/phpunit.xml'" > /root/.bashrc

# purge
RUN \
  apt-get remove -y php8.3-dev gcc make autoconf libc-dev pkg-config php-pear && \
  apt-get autoremove -y && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# node and nvm for playwright
ENV NODE_VERSION=24
ENV NVM_DIR /usr/local/nvm
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

RUN \
  sed -i 's/Components:.*$/Components: main contrib non-free/g' /etc/apt/sources.list.d/debian.sources && apt-get update && \
  cd /tmp && \
  mkdir -p /tmp/playwright && cd /tmp/playwright && \
  mkdir -p $NVM_DIR && \
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash && \
  \. "$NVM_DIR/nvm.sh" && \
  nvm install $NODE_VERSION && \
  nvm alias default $NODE_VERSION && \
  nvm use default && \
  node -v && npm -v && \
  npm install -g -D dotenv && \
  npm install -g -D @playwright/test && \
  npx playwright install --with-deps chromium && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

### drupal download
COPY container/drupal-download.sh /tmp
COPY container/drupalmodule-download.sh /tmp
RUN \
  chmod +x /tmp/drupal-download.sh && \
  chmod +x /tmp/drupalmodule-download.sh

RUN \
  /tmp/drupal-download.sh 10 && \
  mkdir -p /var/www/html/sites/all/modules && \
  /tmp/drupalmodule-download.sh 10 && \
  mkdir -p /var/www/html/log/supervisor && \
  mkdir -p /mnt/neticrm-10/civicrm

### Add drupal 10 related drush
RUN \
  cd /var/www/html && composer update && composer require drush/drush

# we don't have mysql setup on vanilla image
ADD container/my.cnf /etc/mysql/my.cnf

# override supervisord to prevent conflict
ADD container/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# add initial script
ADD container/init-10.sh /init.sh

WORKDIR /mnt/neticrm-10/civicrm
CMD ["/usr/bin/supervisord"]
