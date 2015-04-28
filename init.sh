#!/bin/bash
DRUPAL="7.32"
NETICRM="2.0-dev"
DB=neticrmci
PW=123456
PORT=80

BASE="/var/www"

echo "Starting MySQL server..."
/usr/bin/mysqld_safe >/dev/null 2>&1 &
sleep 5s
echo "Install new database $DB"
mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
mysql -uroot -e "FLUSH PRIVILEGES;"

cd $BASE

echo "Install Drupal ..."
sleep 5s
php -d sendmail_path=`which true` ~/composer/vendor/bin/drush.php --yes core-quick-drupal --core=drupal-${DRUPAL} --no-server --db-url=mysql://${DB}:${PW}@127.0.0.1/${DB} --account-pass=123456 --site-name=netiCRM --enable=transliteration neticrm_build
mv $BASE/neticrm_build/drupal-${DRUPAL} $BASE/html

echo "Install netiCRM ..."
sleep 5s
cd ${BASE}/html/sites/all/modules
git clone --depth=50 --branch=2.0-dev git://github.com/NETivism/netiCRM.git civicrm
cd civicrm
git submodule init
git submodule update
php ~/composer/vendor/bin/drush.php --yes --debug pm-enable civicrm

# start php
echo "Startup php server at $PORT ..."
sleep 5s
mkdir ${BASE}/html/log
chown -R www-data /var/www/html/sites/default/files
/usr/sbin/apache2ctl -D FOREGROUND > /dev/null 2>&1 &

# testing...
echo "Running testing..."
# headless browser testing..
echo "Headless testing"
sleep 5s
cd $BASE/html
casperjs test sites/all/modules/civicrm/tests/casperjs/pages.js


/bin/bash
