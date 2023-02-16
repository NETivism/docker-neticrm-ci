#!/bin/bash
VERSION_PREFIX=$1
LATEST_VERSION=$(curl -s "https://www.drupal.org/node/3060/release/feed?version=$VERSION_PREFIX" | grep '<title>drupal' | head -1 | sed 's/[^0-9.]*//g' | tr -d '\n')
echo "Downloading Drupal $LATEST_VERSION ..."
curl -s "https://ftp.drupal.org/files/projects/drupal-${LATEST_VERSION}.tar.gz" | tar -xz -C /tmp
if [ ! -d /var/www/html ]; then
  mkdir -p /var/www/html
fi
mv "/tmp/drupal-$LATEST_VERSION/{.,}*" /var/www/html/
