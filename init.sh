#!/bin/bash
DRUPAL="7.32"
NETICRM="2.0-dev"
DB=neticrmci
PW=123456
PORT=8888

DIR="neticrm-${NETICRM}"

echo "Starting MySQL server..."
/usr/bin/mysqld_safe >/dev/null 2>&1 &
sleep 5s
echo "Install new database $DB"
mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
mysql -uroot -e "FLUSH PRIVILEGES;"

cd /home

echo "Install Drupal ..."
sleep 5s
php -d sendmail_path=`which true` ~/composer/vendor/bin/drush.php --yes core-quick-drupal --core=drupal-${DRUPAL} --no-server --db-url=mysql://${DB}:${PW}@127.0.0.1/${DB} --account-pass=123456 --site-name=netiCRM --enable=transliteration ${DIR}

echo "Install netiCRM ..."
sleep 5s
cd ${DIR}/drupal-${DRUPAL}/sites/all/modules
git clone --depth=50 --branch=2.0-dev git://github.com/NETivism/netiCRM.git civicrm
cd civicrm
git submodule init
git submodule update
php ~/composer/vendor/bin/drush.php --yes pm-enable civicrm

# start php
echo "Startup php server at $PORT ..."
sleep 5s
php ~/composer/vendor/bin/drush.php runserver 127.0.0.1:$PORT >> /dev/null &

/bin/bash
