#!/bin/bash
sleep 10
while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done

REPOSDIR=`pwd`
export DRUPAL_ROOT=/var/www/html
DRUPAL=$DRUPAL
NETICRM=$NETICRM
DB="neticrmci"
PW="123456"
export RUNPORT=8080

echo "export TERM=xterm" >> /root/.bashrc
echo "export DRUPAL_ROOT=/var/www/html" >> /root/.bashrc
echo "export CIVICRM_TEST_DSN=mysql://root@127.0.0.1/neticrmci" >> /root/.bashrc
export CIVICRM_TEST_DSN=mysql://root@127.0.0.1/neticrmci

date +"@ %Y-%m-%d %H:%M:%S %z"
echo "CI for Drupal-$DRUPAL + netiCRM-$NETICRM"

echo "Install new database $DB"
mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"

cd $DRUPAL_ROOT

echo "Install Drupal ..."
date +"@ %Y-%m-%d %H:%M:%S %z"
sleep 5s
php -d sendmail_path=`which true` ~/.composer/vendor/bin/drush.php --yes site-install standard --account-name=admin --db-url=mysql://root:@127.0.0.1/$DB --account-pass=$PW --site-name=netiCRM

echo "Install netiCRM ..."
cp -R $REPOSDIR $DRUPAL_ROOT/sites/all/modules/civicrm
cd $DRUPAL_ROOT
drush --yes pm-enable transliteration simpletest
drush --yes pm-enable civicrm
drush --yes pm-enable civicrm_allpay civicrm_neweb civicrm_spgateway
drush --yes variable-set civicrm_demo_sample_data 1
drush --yes pm-enable civicrm_demo
drush --yes variable-set error_level 0

chown -R www-data /var/www/html/sites/default/files
echo 'date_default_timezone_set("Asia/Taipei");' >> $DRUPAL_ROOT/sites/default/settings.php
echo 'ini_set("error_reporting", E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED & ~E_WARNING);' >> $DRUPAL_ROOT/sites/default/settings.php

drush runserver 127.0.0.1:$RUNPORT >& /dev/null &
until netstat -an 2>/dev/null | grep "${RUNPORT}.*LISTEN"; do true; done

# testing...
echo "Running test..."
