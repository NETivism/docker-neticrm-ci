#!/bin/bash
if [ -z $1 ]; then
  echo "Please specify drupal version prefix."
  exit;
fi
VERSION_PREFIX=$1
LATEST_VERSION=$(curl -s "https://www.drupal.org/node/3060/release/feed?version=$VERSION_PREFIX" | grep '<title>drupal' | grep -v 'alpha\|beta\|dev' | head -1 | sed 's/[^0-9.]*//g' | tr -d '\n')

if [ -d /tmp/drupal-${LATEST_VERSION} ]; then
  echo "Directory /tmp/drupal-${LATEST_VERSION} exists. Delete directory for download newest file."
  rm -Rf /tmp/drupal-${LATEST_VERSION}
fi
echo "Downloading Drupal $LATEST_VERSION ..."
curl -s "https://ftp.drupal.org/files/projects/drupal-${LATEST_VERSION}.tar.gz" | tar -xz -C /tmp
if [ ! -d /var/www/html ]; then
  mkdir -p /var/www/html
fi
mv /tmp/drupal-$LATEST_VERSION/* /tmp/drupal-$LATEST_VERSION/.[!.]* /var/www/html/
rm -Rf /tmp/drupal-$LATEST_VERSION
echo "Drupal $LATEST_VERSION downloaded on /var/www/html"
