FROM ghcr.io/netivism/docker-debian-php:8.3
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

### ci tools
ENV \
  PATH=$PATH:/root/phpunit \
  PHANTOMJS_VERSION=1.9.8

RUN \
  apt-get update

#phpunit
RUN \
  mkdir -p /root/phpunit/extensions && \
  wget -O /root/phpunit/phpunit https://phar.phpunit.de/phpunit-10.phar && \
  chmod +x /root/phpunit/phpunit && \
  cp /home/docker/php/phpunit.xml /root/phpunit/ && \
  echo "alias phpunit='phpunit -c ~/phpunit/phpunit.xml'" > /root/.bashrc

# node and nvm for playwright
ENV NODE_VERSION=20.19.5
ENV NVM_DIR /usr/local/nvm
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

RUN \
  sed -i 's/main$/main contrib non-free/g' /etc/apt/sources.list && apt-get update && \
  cd /tmp && \
  mkdir -p /tmp/playwright && cd /tmp/playwright && \
  mkdir -p $NVM_DIR && \
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
  \. "$NVM_DIR/nvm.sh" && \
  nvm install $NODE_VERSION && \
  nvm alias default $NODE_VERSION && \
  nvm use default && \
  node -v && npm -v && \
  npm install -g -D dotenv && \
  npm install -g -D @playwright/test && \
  npx playwright install --with-deps chromium

# cgi
RUN \
  apt-get install -y php8.3-cgi net-tools

# purge
RUN \
  apt-get remove -y gcc make autoconf libc-dev pkg-config php-pear && \
  apt-get autoremove -y && \
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
