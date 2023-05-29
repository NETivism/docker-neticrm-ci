#!/bin/bash
sleep 10
while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done

REPOSDIR=`pwd`
if [ ! -f $REPOSDIR/civicrm-version.txt ]; then
  REPOSDIR='/mnt/neticrm-10/civicrm'
fi
export DRUPAL_ROOT=/var/www/html
DB="neticrmci"
PW="123456"
export RUNPORT=8080

echo "export TERM=xterm" >> /root/.bashrc
echo "export DRUPAL_ROOT=/var/www/html" >> /root/.bashrc
echo "export CIVICRM_TEST_DSN=mysqli://root@localhost/neticrmci" >> /root/.bashrc
export CIVICRM_TEST_DSN=mysqli://root@localhost/neticrmci

date +"@ %Y-%m-%d %H:%M:%S %z"
echo "CI for Drupal-$DRUPAL + netiCRM"

EXISTSDB=`mysql -uroot -e "SHOW DATABASES" | grep neticrmci | wc -l`
if [ "$EXISTSDB" = "0" ]; then
  echo "Install new database $DB"
  mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
fi

cd $DRUPAL_ROOT

if [ ! -f $DRUPAL_ROOT/sites/default/settings.php ]; then
  echo "Install Drupal ..."
  date +"@ %Y-%m-%d %H:%M:%S %z"
  sleep 5s
  drush -vv --yes site-install standard --account-name=admin --db-url=mysql://root:@localhost/$DB --account-pass=$PW --site-name=netiCRM

  if [ -f $DRUPAL_ROOT/sites/default/settings.php ]; then
    echo 'date_default_timezone_set("Asia/Taipei");' >> $DRUPAL_ROOT/sites/default/settings.php
    echo 'ini_set("error_reporting", E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED & ~E_WARNING);' >> $DRUPAL_ROOT/sites/default/settings.php
    echo "\$base_url='';" >> $DRUPAL_ROOT/sites/default/settings.php
    echo "\$settings['civicrm_demo.sample_data_ci'] = TRUE;" >> $DRUPAL_ROOT/sites/default/settings.php
    echo "\$config['system.performance']['js']['preprocess'] = FALSE;" >> $DRUPAL_ROOT/sites/default/settings.php
  fi

  echo "Install netiCRM ..."
  ln -s $REPOSDIR $DRUPAL_ROOT/modules/civicrm
  cd $DRUPAL_ROOT

  #drush --yes pm:install civicrm
  #drush --yes pm:install civicrm_allpay 
  #drush --yes pm:install neticrm_drush
  #drush --yes pm:install civicrm_demo

  # add permission for unit testing
  #drush role-add-perm anonymous 'profile create'
  #drush role-add-perm authenticated 'profile create,profile edit'

  # add user login block to front page
  mkdir /tmp/config
  printf "langcode: en\nstatus: true\ndependencies:\n  module:\n    - user\n  theme:\n    - olivero\nid: userlogin\ntheme: olivero\nregion: sidebar\nweight: 0\nprovider: null\nplugin: user_login_block\nsettings:\n  id: user_login_block\n  label: 'User login'\n  label_display: visible\n  provider: user\nvisibility: {  }" > /tmp/config/block.block.userlogin.yml
  drush --yes config:import --source=/tmp/config --partial

  chown -R www-data /var/www/html/sites/default/files
fi

drush runserver 0.0.0.0:$RUNPORT >& /dev/null &
until netstat -an 2>/dev/null | grep "${RUNPORT}.*LISTEN"; do true; done

# initialize playwright
echo "Link playwright for testing project"
if [ -d $DRUPAL_ROOT/modules/civicrm/tests/playwright ]; then
  cd $DRUPAL_ROOT/modules/civicrm/tests/playwright 
  npm link @playwright/test
  npm link dotenv

  npx playwright install --with-deps chromium
  cd $DRUPAL_ROOT
fi

# testing...
echo "Running test..."

