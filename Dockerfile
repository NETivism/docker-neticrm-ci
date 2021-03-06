FROM netivism/docker-wheezy-php55
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

ENV \
  COMPOSER_HOME=/root/.composer \
  PATH=/root/.composer/vendor/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  PHANTOMJS_VERSION=1.9.7

# composer
RUN \
  apt-get update && \
  apt-get install -y \
    supervisor \
    net-tools \
    gawk && \
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
  composer global require drush/drush:6.5.0 && \
  composer global require phpunit/phpunit:4.6 && \
  composer global require phpunit/dbunit

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
  rm -rf /var/lib/apt/lists/* && \
  mkdir -p /var/www/html/log/supervisor

ADD container/init.sh /init.sh
ADD container/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD container/ansi2html.sh /usr/local/bin/ansi2html

WORKDIR /var/www/html
CMD ["/usr/bin/supervisord"]
