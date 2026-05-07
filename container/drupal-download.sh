#!/bin/bash
if [ -z $1 ]; then
  echo "Please specify drupal version prefix."
  exit;
fi
VERSION_PREFIX=$1
LATEST_VERSION=$(curl -s "https://www.drupal.org/node/3060/release/feed" | grep -oE '<link>https://www\.drupal\.org/project/drupal/releases/[0-9]+\.[0-9]+\.[0-9]+</link>' | sed -E 's|<link>https://www\.drupal\.org/project/drupal/releases/([0-9]+\.[0-9]+\.[0-9]+)</link>|\1|' | grep "^${VERSION_PREFIX}\." | sort -V -r | head -1)

if [ -z "$LATEST_VERSION" ] && [ "$VERSION_PREFIX" != "7" ]; then
  echo "Error: No Drupal release matched version prefix '${VERSION_PREFIX}'." >&2
  exit 1
fi

if [ -d /tmp/drupal-${LATEST_VERSION} ]; then
  echo "Directory /tmp/drupal-${LATEST_VERSION} exists. Delete directory for download newest file."
  rm -Rf /tmp/drupal-${LATEST_VERSION}
fi
if [ ! -d /var/www/html ]; then
  mkdir -p /var/www/html
fi
if [ $VERSION_PREFIX = "7" ]; then
  LATEST_VERSION="7.x"
  echo "Downloading Drupal $LATEST_VERSION ..."
  wget https://github.com/NETivism/drupal/archive/refs/heads/7.x.tar.gz -O /tmp/drupal.tar.gz
  tar -zxf /tmp/drupal.tar.gz -C /var/www/html --strip-components=1
  rm -Rf /tmp/drupal.tar.gz
else
  echo "Downloading Drupal $LATEST_VERSION ..."
  curl -s "https://ftp.drupal.org/files/projects/drupal-${LATEST_VERSION}.tar.gz" | tar -xz -C /tmp
  mv /tmp/drupal-$LATEST_VERSION/* /tmp/drupal-$LATEST_VERSION/.[!.]* /var/www/html/
  rm -Rf /tmp/drupal-$LATEST_VERSION
fi
echo "Drupal $LATEST_VERSION downloaded on /var/www/html"
