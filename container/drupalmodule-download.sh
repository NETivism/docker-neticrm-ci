#!/bin/bash
VERSION_PREFIX=$1
if [ $VERSION_PREFIX = "7" ]; then
  curl -s https://ftp.drupal.org/files/projects/transliteration-7.x-3.2.tar.gz | tar -zx -C /var/www/html/sites/all/modules
  curl -s https://ftp.drupal.org/files/projects/simpletest-7.x-2.1.tar.gz | tar -zx -C /var/www/html/sites/all/modules
fi
