FROM netivism/docker-wheezy-php55
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

# composer
ENV COMPOSER_HOME /root/composer
RUN \
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=1.0.0-alpha8 && \
  composer global require drush/drush:6.5.0

ADD init.sh /init.sh
