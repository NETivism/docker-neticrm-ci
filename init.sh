#!/bin/bash

while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done

BASE="/var/www"
DRUPAL=$DRUPAL
NETICRM=$NETICRM
DB=neticrmci
PW=123456
PORT=80

echo "CI for Drupal-$DRUPAL + netiCRM-$NETICRM"

echo "Install new database $DB"
mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
mysql -uroot -e "FLUSH PRIVILEGES;"

cd $BASE

echo "Install Drupal ..."
sleep 5s
php -d sendmail_path=`which true` ~/composer/vendor/bin/drush.php --yes core-quick-drupal --core=drupal-${DRUPAL} --no-server --db-url=mysql://${DB}:${PW}@127.0.0.1/${DB} --account-pass=123456 --site-name=netiCRM --enable=transliteration neticrm_build
mv $BASE/neticrm_build/drupal-${DRUPAL}/* $BASE/html/
mv $BASE/neticrm_build/drupal-${DRUPAL}/.htaccess $BASE/html/

echo "Install netiCRM ..."
cat $BASE/html/ci.log | ansi2html -f 15px > $BASE/html/ci.html

sleep 5s
cd ${BASE}/html/sites/all/modules
git clone --depth=50 --branch=2.0-dev git://github.com/NETivism/netiCRM.git civicrm
cd civicrm
git submodule init
git submodule update
php ~/composer/vendor/bin/drush.php --yes pm-enable civicrm

# start php
echo "Startup php server at $PORT ..."
sleep 5s
chown -R www-data /var/www/html/sites/default/files

# testing...
echo "Running testing..."
cat $BASE/html/ci.log | ansi2html -f 15px > $BASE/html/ci.html

# headless browser testing..
echo "Headless testing"
sleep 5s
cd $BASE/html
casperjs test sites/all/modules/civicrm/tests/casperjs/pages.js

# export testing log to html
cat $BASE/html/ci.log | ansi2html --bg=dark > $BASE/html/ci.html
