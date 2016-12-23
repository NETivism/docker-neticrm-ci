#!/bin/bash

while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done

BASE="/var/www"
mkdir -p $BASE/www
DRUPAL=$DRUPAL
NETICRM=$NETICRM
DB=neticrmci
PW=123456
PORT=80

echo "export TERM=xterm" >> /root/.bashrc
echo "export DRUPAL_ROOT=/var/www/html" >> /root/.bashrc
echo "export CIVICRM_TEST_DSN=mysql://root@127.0.0.1/neticrmci" >> /root/.bashrc

date +"@ %Y-%m-%d %H:%M:%S %z"
echo "CI for Drupal-$DRUPAL + netiCRM-$NETICRM"

echo "Install new database $DB"
mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
mysql -uroot -e "FLUSH PRIVILEGES;"

# phpunit
echo "CiviCRM Unit Testing"
date +"@ %Y-%m-%d %H:%M:%S %z"
export DRUPAL_ROOT=/var/www/html
export CIVICRM_TEST_DSN=mysql://root@127.0.0.1/neticrmci

cd $BASE

echo "Install Drupal ..."
date +"@ %Y-%m-%d %H:%M:%S %z"
sleep 5s
php -d sendmail_path=`which true` ~/.composer/vendor/bin/drush.php --yes core-quick-drupal --core=drupal-$DRUPAL --no-server --db-url=mysql://root:${PW}@127.0.0.1/neticrmci --account-pass=123456 --site-name=netiCRM --enable=transliteration neticrmci

mv $BASE/neticrmci/drupal-${DRUPAL}/* $BASE/html/
mv $BASE/neticrmci/drupal-${DRUPAL}/.htaccess $BASE/html/

echo "Install netiCRM ..."
date +"@ %Y-%m-%d %H:%M:%S %z"
cat $BASE/html/ci.log | ansi2html --bg=dark > $BASE/html/ci.html

sleep 5s
cd ${BASE}/html/sites/all/modules
git clone --depth=50 --branch=develop git://github.com/NETivism/netiCRM.git civicrm
cd civicrm
git submodule init
git submodule update
drush --yes pm-download simpletest
drush --yes pm-enable civicrm simpletest
drush --yes pm-enable civicrm_allpay civicrm_neweb civicrm_spgateway
drush --yes variable-set civicrm_demo_sample_data 1
drush --yes pm-enable civicrm_demo
drush --yes variable-set error_level 0

chown -R www-data /var/www/html/sites/default/files
echo 'date_default_timezone_set("Asia/Taipei");' >> $DRUPAL_ROOT/sites/default/settings.php
echo 'ini_set("error_reporting", E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED & ~E_WARNING);' >> $DRUPAL_ROOT/sites/default/settings.php

# testing...
echo "Running test..."
cat $BASE/html/ci.log | ansi2html --bg=dark > $BASE/html/ci.html

# headless browser testing..
echo "Unit testing"

date +"@ %Y-%m-%d %H:%M:%S %z"
echo "Testing Allpay"
cd $DRUPAL_ROOT/sites/all/modules/civicrm/tests/phpunit && phpunit CRM/Core/Payment/ALLPAYTest.php

date +"@ %Y-%m-%d %H:%M:%S %z"
echo "Testing Neweb"
cd $DRUPAL_ROOT/sites/all/modules/civicrm/tests/phpunit && phpunit CRM/Core/Payment/NewebTest.php

date +"@ %Y-%m-%d %H:%M:%S %z"
echo "Testing SPGATEWAY"
cd $DRUPAL_ROOT/sites/all/modules/civicrm/tests/phpunit && phpunit CRM/Core/Payment/SPGATEWAYTest.php

#date +"@ %Y-%m-%d %H:%M:%S %z"
#echo "Testing CiviCRM API"
#phpunit --colors=always CRM/api/v3/AllTests.php

date +"@ %Y-%m-%d %H:%M:%S %z"
cat $DRUPAL_ROOT/ci.log | ansi2html --bg=dark > $DRUPAL_ROOT/ci.html

echo "Headless testing"
date +"@ %Y-%m-%d %H:%M:%S %z"
sleep 10s
cd $DRUPAL_ROOT

casperjs test sites/all/modules/civicrm/tests/casperjs/pages.js
cat $DRUPAL_ROOT/ci.log | ansi2html --bg=dark > $DRUPAL_ROOT/ci.html
sleep 3s

casperjs test sites/all/modules/civicrm/tests/casperjs/event_register.js
cat $DRUPAL_ROOT/ci.log | ansi2html --bg=dark > $DRUPAL_ROOT/ci.html
sleep 3s
casperjs test sites/all/modules/civicrm/tests/casperjs/contribution_allpay.js
cat $DRUPAL_ROOT/ci.log | ansi2html --bg=dark > $DRUPAL_ROOT/ci.html
sleep 3s
casperjs test sites/all/modules/civicrm/tests/casperjs/contribution_allpay_atm.js
cat $DRUPAL_ROOT/ci.log | ansi2html --bg=dark > $DRUPAL_ROOT/ci.html
sleep 3s
casperjs test sites/all/modules/civicrm/tests/casperjs/contribution_allpay_barcode.js
cat $DRUPAL_ROOT/ci.log | ansi2html --bg=dark > $DRUPAL_ROOT/ci.html
sleep 3s
