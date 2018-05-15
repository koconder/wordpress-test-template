# Wordpress CI Testing Template

[![Build Status](https://travis-ci.org/koconder/wordpress-test-template.svg?branch=master)](https://travis-ci.org/koconder/wordpress-test-template) [![codecov](https://codecov.io/gh/koconder/wordpress-test-template/branch/master/graph/badge.svg)](https://codecov.io/gh/koconder/wordpress-test-template)

Template for using Travis CI with PHPUnit, PHPCodeSniffer, and Rspec tests in your wordpress projects.
Built on the previous work by Koodimonni, also based on testing libraries from wp-cli/wp-cli and woocommerce/woocommerce

## Configuration
### Travis Enviromental variables

```WP_PROJECT_TYPE``` use 'plugin' or 'theme'

```WP_VERSION``` use latest or number (eg. 4.0.1)

```WP_MULTISITE``` use 0 or 1. TODO: this is not working yet

## Examples
### Basic: Just drop following .travis.yml in your project and start using phantomjs to do basic wordpress testing every time you push to github.
```yaml
# This uses newer and faster docker based build system
sudo: false

language: php

notifications:
  on_success: never
  on_failure: change

php:
  - nightly # PHP 7.0
  - 5.6
  - 5.5
  - 5.4

env:
  - WP_PROJECT_TYPE=plugin WP_VERSION=latest WP_MULTISITE=0 WP_TEST_URL=http://localhost:12000 WP_TEST_USER=test WP_TEST_USER_PASS=test

matrix:
  allow_failures:
    - php: nightly

before_script:
  # Install composer packages before trying to activate themes or plugins
  # - composer install

  - git clone https://github.com/Koodimonni/wordpress-test-template wp-tests
  - bash wp-tests/bin/install-wp-tests.sh test root '' localhost $WP_VERSION

script:
  - cd wp-tests/spec && bundle exec rspec test.rb

```

### Example of using custom rspec tests
1. Copy spec/ folder from this repo into your repo root
2. Add custom tests
3. Add this into your .travis.yml

```yaml
# This uses newer and faster docker based build system
sudo: false

language: php

notifications:
  on_success: never
  on_failure: change

php:
  - nightly # PHP 7.0
  - 5.6
  - 5.5
  - 5.4

env:
  - WP_PROJECT_TYPE=plugin WP_VERSION=latest WP_MULTISITE=0 WP_TEST_URL=http://localhost:12000 WP_TEST_USER=test WP_TEST_USER_PASS=test

matrix:
  allow_failures:
    - php: nightly

before_script:
  # Install composer packages before trying to activate themes or plugins
  # - composer install

  - git clone https://github.com/Koodimonni/wordpress-test-template wp-tests
  - bash wp-tests/bin/install-wp-tests.sh test root '' localhost $WP_VERSION

script:
  - cd spec && bundle exec rspec test.rb
```

### Example of using custom phpunit tests
1. Copy tests/ folder and phpunit.xml from this repo into your repo root
2. Use your plugin filename in phpunit.xml:

```xml
...
<env>
  <!-- Enter the name of your main plugin file here -->
  <env name="PLUGIN_FILE" value="plugin.php"/>
</env>
...
```

3. Add this into your .travis.yml

```yaml
# This uses newer and faster docker based build system
sudo: false

language: php

notifications:
  on_success: never
  on_failure: change

php:
  - nightly # PHP 7.0
  - 5.6
  - 5.5
  - 5.4

env:
  - WP_PROJECT_TYPE=plugin WP_VERSION=latest WP_MULTISITE=0 WP_TEST_URL=http://localhost:12000 WP_TEST_USER=test WP_TEST_USER_PASS=test

matrix:
  allow_failures:
    - php: nightly

before_script:
  # Install composer packages before trying to activate themes or plugins
  # - composer install

  - git clone https://github.com/Koodimonni/wordpress-test-template wp-tests
  - bash wp-tests/bin/install-wp-tests.sh test root '' localhost $WP_VERSION

script:
  - phpunit
```

### Example of validating WordPress PHP coding standards 
1. Add this into your .travis.yml

```yaml
# This uses newer and faster docker based build system
sudo: false

language: php

notifications:
  on_success: never
  on_failure: change

php:
  - nightly # PHP 7.0
  - 5.6
  - 5.5
  - 5.4

env:
  - WP_PROJECT_TYPE=plugin WP_VERSION=latest WP_MULTISITE=0 WP_TEST_URL=http://localhost:12000 WP_TEST_USER=test WP_TEST_USER_PASS=test

matrix:
  allow_failures:
    - php: nightly

before_script:
  # Install composer packages before trying to activate themes or plugins
  # - composer install

  - git clone https://github.com/Koodimonni/wordpress-test-template wp-tests
  - bash wp-tests/bin/install-wp-tests.sh test root '' localhost $WP_VERSION

script:
  - phpcs --standard=WordPress ./**/*.php
```

