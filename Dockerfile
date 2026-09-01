FROM ghcr.io/netivism/docker-debian-base:trixie
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

ENV \
  COMPOSER_HOME=/root/.composer \
  PATH=/root/.composer/vendor/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# basic packages install
RUN \
    apt-get update && \
    apt-get install -y rsyslog apt-transport-https wget gnupg google-perftools qpdf curl vim git-core supervisor procps net-tools

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
    php8.3-cgi \
    php8.3-cli \
    php8.3-curl \
    php8.3-imap \
    php8.3-gd \
    php8.3-mysql \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-memcached \
    php8.3-zip \
    php8.3-bz2 \
    php8.3-ssh2 \
    php8.3-yaml

RUN \
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
  cd /root/.composer && \
  find . | grep .git | xargs rm -rf && \
  composer clearcache

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
  git clone https://github.com/NETivism/docker-sh.git /home/docker && \
  mkdir -p /root/phpunit/extensions && \
  wget -O /root/phpunit/phpunit https://phar.phpunit.de/phpunit-10.phar && \
  chmod +x /root/phpunit/phpunit && \
  cp /home/docker/php/phpunit.xml /root/phpunit/ && \
  echo "alias phpunit='phpunit -c ~/phpunit/phpunit.xml'" > /root/.bashrc


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
  ln -sfn "$NVM_DIR/versions/node/$(node -v)" "$NVM_DIR/versions/node/v$NODE_VERSION" && \
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
COPY container/mysql-init.sh /usr/local/bin/mysql-init.sh
ADD container/my.cnf /etc/mysql/my.cnf

# override supervisord to prevent conflict
ADD container/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# add initial script
ADD container/init-10.sh /init.sh

# purge
RUN \
  apt-get autoremove -y && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /mnt/neticrm-10/civicrm
CMD ["/usr/bin/supervisord"]
