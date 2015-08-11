#!/bin/bash

while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done

BASE="/var/www"
DRUPAL=$DRUPAL
NETICRM=$NETICRM
DB=neticrmci
PW=123456
PORT=80

date +"@ %Y-%m-%d %H:%M:%S %z"
echo "CI for Drupal-$DRUPAL + netiCRM-$NETICRM"

echo "Install new database $DB"
mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
mysql -uroot -e "FLUSH PRIVILEGES;"

cd $BASE

echo "Install Drupal ..."
date +"@ %Y-%m-%d %H:%M:%S %z"
sleep 5s
php -d sendmail_path=`which true` ~/.composer/vendor/bin/drush.php --yes core-quick-drupal --core=drupal-${DRUPAL} --no-server --db-url=mysql://${DB}:${PW}@127.0.0.1/${DB} --account-pass=123456 --site-name=netiCRM --enable=transliteration neticrm_build
mv $BASE/neticrm_build/drupal-${DRUPAL}/* $BASE/html/
mv $BASE/neticrm_build/drupal-${DRUPAL}/.htaccess $BASE/html/

echo "Install netiCRM ..."
date +"@ %Y-%m-%d %H:%M:%S %z"
cat $BASE/html/ci.log | ansi2html --bg=dark > $BASE/html/ci.html

sleep 5s
cd ${BASE}/html/sites/all/modules
git clone --depth=50 --branch=2.0-dev git://github.com/NETivism/netiCRM.git civicrm
cd civicrm
git submodule init
git submodule update
drush --yes pm-enable civicrm
drush en civicrm_allpay --yes
drush en civicrm_demo --yes

chown -R www-data /var/www/html/sites/default/files

# testing...
echo "Running test..."
cat $BASE/html/ci.log | ansi2html --bg=dark > $BASE/html/ci.html

# headless browser testing..
echo "Headless testing"
date +"@ %Y-%m-%d %H:%M:%S %z"
sleep 10s
cd $BASE/html
casperjs test sites/all/modules/civicrm/tests/casperjs/pages.js
casperjs test sites/all/modules/civicrm/tests/casperjs/contribution_allpay.js

# export testing log to html
cat $BASE/html/ci.log | ansi2html --bg=dark > $BASE/html/ci.html

# phpunit 
echo "CiviCRM Unit Testing"
date +"@ %Y-%m-%d %H:%M:%S %z"
cd $BASE/html/sites/all/modules/civicrm/tests/phpunit
export DRUPAL_ROOT=/var/www/html
export CIVICRM_TEST_DSN=mysql://root@127.0.0.1/neticrmci

date +"@ %Y-%m-%d %H:%M:%S %z"
echo "Testing Allpay"
phpunit --colors=always CRM/Core/Payment/ALLPAYTest.php

#date +"@ %Y-%m-%d %H:%M:%S %z"
#echo "Testing Neweb"
#phpunit --colors=always CRM/Core/Payment/NewebTest.php

#date +"@ %Y-%m-%d %H:%M:%S %z"
#echo "Testing CiviCRM API"
#phpunit --colors=always CRM/api/v3/AllTests.php

date +"@ %Y-%m-%d %H:%M:%S %z"
cat $BASE/html/ci.log | ansi2html --bg=dark > $BASE/html/ci.html
