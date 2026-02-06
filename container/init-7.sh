#!/bin/bash
date +"@ %Y-%m-%d %H:%M:%S %z"

# wait for mysql start
while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done
sleep 10

REPOSDIR=`pwd`
if [ ! -f $REPOSDIR/civicrm-version.txt ]; then
  REPOSDIR='/mnt/neticrm-7/civicrm'
fi
export DRUPAL_ROOT=/var/www/html
DB="neticrmci"
PW="123456"
export RUNPORT=8080

echo "export TERM=xterm" >> /root/.bashrc
echo "export DRUPAL_ROOT=/var/www/html" >> /root/.bashrc
echo "export CIVICRM_TEST_DSN=mysqli://root@localhost/neticrmci" >> /root/.bashrc
export CIVICRM_TEST_DSN=mysqli://root@localhost/neticrmci
export DRUPAL=7

date +"@ %Y-%m-%d %H:%M:%S %z"
echo "CI for Drupal-$DRUPAL + netiCRM"

# correct drush installation
## update composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
composer global remove drush/drush
composer global require drush/drush:8.5.0 --no-security-blocking --no-audit

# init mysql
DB_TEST=`mysql -uroot -sN -e "SHOW databases"`
MYSQL_ACCESS=$?
DB_EXISTS=`mysql -uroot -sN -e "SHOW databases" | grep $DB`

if [ $MYSQL_ACCESS -eq 0 ] && [ -z "$DB_EXISTS" ] && [ -n "$DB" ]; then
  echo "Install new database $DB"
  mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
  echo "MySQL initialize completed !!"
  echo "MYSQL_DB=$DB"
else
  echo "Skip exist $DB, database already setup before."
fi

cd $DRUPAL_ROOT

if [ ! -f $DRUPAL_ROOT/sites/default/settings.php ]; then
  date +"@ %Y-%m-%d %H:%M:%S %z"
  echo "Install Drupal ..."
  sleep 5s
  php ~/.composer/vendor/bin/drush.php --yes site-install standard --account-name=admin --db-url=mysql://root:@localhost/$DB --account-pass=$PW --site-name=netiCRM

  echo "Install netiCRM ..."
  ln -s $REPOSDIR $DRUPAL_ROOT/sites/all/modules/civicrm
  cd $DRUPAL_ROOT
  drush --yes pm-enable transliteration simpletest
  drush --yes pm-enable civicrm
  drush --yes pm-enable civicrm_allpay civicrm_neweb civicrm_spgateway
  drush --yes pm-enable neticrm_drush
  drush --yes variable-set civicrm_demo_sample_data 1
  drush --yes variable-set civicrm_demo_sample_data_ci 1
  drush --yes pm-enable civicrm_demo
  drush --yes variable-set error_level 0

  drush role-add-perm 1 'profile create,register for events,access CiviMail subscribe/unsubscribe pages,access all custom data,view event info,view public CiviMail content,make online contributions'
  drush role-add-perm 2 'profile create,register for events,access CiviMail subscribe/unsubscribe pages,access all custom data,view event info,view public CiviMail content,make online contributions,profile edit'

  chown -R www-data /var/www/html/sites/default/files
  echo 'date_default_timezone_set("Asia/Taipei");' >> $DRUPAL_ROOT/sites/default/settings.php
  echo 'ini_set("error_reporting", E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED & ~E_WARNING);' >> $DRUPAL_ROOT/sites/default/settings.php
  echo "\$base_url='';" >> $DRUPAL_ROOT/sites/default/settings.php
fi

drush runserver 0.0.0.0:$RUNPORT >& /dev/null &
until netstat -an 2>/dev/null | grep "${RUNPORT}.*LISTEN"; do true; done

# initialize playwright
echo "Link playwright for testing project"
if [ -d $DRUPAL_ROOT/sites/all/modules/civicrm/tests/playwright ]; then
  cd $DRUPAL_ROOT/sites/all/modules/civicrm/tests/playwright 
  npm link @playwright/test
  npm link dotenv
  pwd
  echo -e "# .env file\nlocalUrl=http://127.0.0.1:$RUNPORT/\nadminUser=admin\nadminPwd=123456" >> $DRUPAL_ROOT/sites/all/modules/civicrm/tests/playwright/setup.env

  # install latest chromium
  npx playwright install --with-deps chromium
  cd $DRUPAL_ROOT
fi

# testing...
echo "Running test..."
date +"@ %Y-%m-%d %H:%M:%S %z"

