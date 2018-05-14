#!/usr/bin/env bash
##
# This script installs wordpress for phpunit tests and rspec integration tests
##
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
DIR=$(dirname ${DIR})

if [ $# -lt 3 ]; then
echo "usage: $0 <db-name> <db-user> <db-pass> [db-host] [wp-version] [skip-database-creation]"
exit 1
fi

DB_NAME=$1
DB_USER=$2
DB_PASS=$3
DB_HOST=${4-localhost}

WP_VERSION=${5-latest}
SKIP_DB_CREATE=${6-false}

# Use this for installing wordpress siteurl
WP_TEST_URL=${WP_TEST_URL-http://localhost:12000}

# Get port from url
WP_PORT=${WP_TEST_URL##*:}

WP_TESTS_DIR=${WP_TESTS_DIR-/tmp/wordpress-tests-lib/includes}
WP_CORE_DIR=${WP_CORE_DIR-/tmp/wordpress/}

# Use these credentials for installing wordpress
# Default test/test
WP_TEST_USER=${WP_TEST_USER-test}
WP_TEST_USER_PASS=${WP_TEST_USER_PASS-test}

set -ex

download() {
  if [ `which curl` ]; then
    curl -s "$1" > "$2";
  elif [ `which wget` ]; then
    wget -nv -O "$2" "$1"
  fi
}

if [[ $WP_VERSION =~ [0-9]+\.[0-9]+(\.[0-9]+)? ]]; then
  WP_TESTS_TAG="tags/$WP_VERSION"
elif [[ $WP_VERSION == 'nightly' || $WP_VERSION == 'trunk' ]]; then
  WP_TESTS_TAG="trunk"
else
  # http serves a single offer, whereas https serves multiple. we only want one
  download http://api.wordpress.org/core/version-check/1.7/ /tmp/wp-latest.json
  grep '[0-9]+\.[0-9]+(\.[0-9]+)?' /tmp/wp-latest.json
  LATEST_VERSION=$(grep -o '"version":"[^"]*' /tmp/wp-latest.json | sed 's/"version":"//')
  if [[ -z "$LATEST_VERSION" ]]; then
    echo "Latest WordPress version could not be found"
    exit 1
  fi
  WP_TESTS_TAG="tags/$LATEST_VERSION"
fi

set -ex


install_wp() {
  if [ -d $WP_CORE_DIR ]; then
    return;
  fi

  mkdir -p $WP_CORE_DIR

  if [[ $WP_VERSION == 'nightly' || $WP_VERSION == 'trunk' ]]; then
    mkdir -p /tmp/wordpress-nightly
    download https://wordpress.org/nightly-builds/wordpress-latest.zip  /tmp/wordpress-nightly/wordpress-nightly.zip
    unzip -q /tmp/wordpress-nightly/wordpress-nightly.zip -d /tmp/wordpress-nightly/
    mv /tmp/wordpress-nightly/wordpress/* $WP_CORE_DIR
  else
    if [ $WP_VERSION == 'latest' ]; then
      local ARCHIVE_NAME='latest'
    else
      local ARCHIVE_NAME="wordpress-$WP_VERSION"
    fi
    download https://wordpress.org/${ARCHIVE_NAME}.tar.gz  /tmp/wordpress.tar.gz
    tar --strip-components=1 -zxmf /tmp/wordpress.tar.gz -C $WP_CORE_DIR
  fi

  download https://raw.github.com/markoheijnen/wp-mysqli/master/db.php $WP_CORE_DIR/wp-content/db.php
}

install_test_suite() {
  # portable in-place argument for both GNU sed and Mac OSX sed
  if [[ $(uname -s) == 'Darwin' ]]; then
    local ioption='-i .bak'
  else
    local ioption='-i'
  fi

  # set up testing suite if it doesn't yet exist
  if [ ! -d $WP_TESTS_DIR ]; then
    # set up testing suite
    mkdir -p $WP_TESTS_DIR
    svn co --quiet https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/ $WP_TESTS_DIR
  fi

  if [ ! -f wp-tests-config.php ]; then
    download https://develop.svn.wordpress.org/${WP_TESTS_TAG}/wp-tests-config-sample.php "$WP_TESTS_DIR"/wp-tests-config.php
    # remove all forward slashes in the end
    WP_CORE_DIR=$(echo $WP_CORE_DIR | sed "s:/\+$::")
    sed $ioption "s:dirname( __FILE__ ) . '/src/':'$WP_CORE_DIR/':" "$WP_TESTS_DIR"/wp-tests-config.php
    sed $ioption "s/youremptytestdbnamehere/$DB_NAME/" "$WP_TESTS_DIR"/wp-tests-config.php
    sed $ioption "s/yourusernamehere/$DB_USER/" "$WP_TESTS_DIR"/wp-tests-config.php
    sed $ioption "s/yourpasswordhere/$DB_PASS/" "$WP_TESTS_DIR"/wp-tests-config.php
    sed $ioption "s|localhost|${DB_HOST}|" "$WP_TESTS_DIR"/wp-tests-config.php
  fi
}

install_db() {
  if [ ${SKIP_DB_CREATE} = "true" ]; then
    return 0
  fi

  # parse DB_HOST for port or socket references
  local PARTS=(${DB_HOST//\:/ })
  local DB_HOSTNAME=${PARTS[0]};
  local DB_SOCK_OR_PORT=${PARTS[1]};
  local EXTRA=""

  if ! [ -z $DB_HOSTNAME ] ; then
    if [ $(echo $DB_SOCK_OR_PORT | grep -e '^[0-9]\{1,\}$') ]; then
      EXTRA=" --host=$DB_HOSTNAME --port=$DB_SOCK_OR_PORT --protocol=tcp"
    elif ! [ -z $DB_SOCK_OR_PORT ] ; then
      EXTRA=" --socket=$DB_SOCK_OR_PORT"
    elif ! [ -z $DB_HOSTNAME ] ; then
      EXTRA=" --host=$DB_HOSTNAME --protocol=tcp"
    fi
  fi

  # create database
  mysqladmin create $DB_NAME --user="$DB_USER" --password="$DB_PASS"$EXTRA
}

link_this_project() {
  cd $DIR
  local FOLDER_PATH=$(dirname $DIR)
  local FOLDER_NAME=$(basename $FOLDER_PATH)
  case $WP_PROJECT_TYPE in
    'plugin' )
        ln -s $FOLDER_PATH $WP_CORE_DIR/wp-content/plugins/$FOLDER_NAME
        php wp-cli.phar plugin activate --all --path=$WP_CORE_DIR
        ;;
    'theme' )
        ln -s $FOLDER_PATH $WP_CORE_DIR/wp-content/themes/$FOLDER_NAME
        php wp-cli.phar theme activate $FOLDER_NAME --path=$WP_CORE_DIR
        ;;
  esac
}

# Install databases with wp-cli
install_real_wp() {
  cd $DIR
  download https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar wp-cli.phar
  php wp-cli.phar core install  --url=$WP_TEST_URL --title='Test' --admin_user=$WP_TEST_USER --admin_password=$WP_TEST_USER_PASS --admin_email="$WP_TEST_USER@wordpress.dev" --path=$WP_CORE_DIR
}

install_rspec_requirements() {
  gem install bundler
  bundle install --gemfile=$DIR/spec/Gemfile
}

start_server() {
  mv $DIR/lib/router.php $WP_CORE_DIR/router.php
  cd $WP_CORE_DIR
  # Start it in background
  php -S 0.0.0.0:$WP_PORT router.php &
}

run_phpcs() {
  pear config-set auto_discover 1
  pear install PHP_CodeSniffer
  git clone git://github.com/WordPress-Coding-Standards/WordPress-Coding-Standards.git $(pear config-get php_dir)/PHP/CodeSniffer/Standards/WordPress
  phpenv rehash
  npm install -g jshint
  phpcs --config-set installed_paths $(pear config-get php_dir)/PHP/CodeSniffer/Standards/WordPress
  phpcs -i
}

install_wp
install_test_suite
install_db
install_real_wp
link_this_project
install_rspec_requirements
start_server
run_phpcs
