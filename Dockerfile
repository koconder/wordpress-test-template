ARG PHP_IMAGE_TAG
FROM php:$PHP_IMAGE_TAG
ARG WORDPRESS_VERSION
# Setup Linux Enviroment
RUN echo "http://dl-3.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories &&\
    apk add --update --no-cache subversion mysql mysql-client git bash g++ make autoconf wget && \
    set -ex; \
    docker-php-ext-install mysqli pdo pdo_mysql pcntl \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/bin --filename=composer \
    && docker-php-source extract \
    && pecl install xdebug-2.5.5 \
    && docker-php-ext-enable xdebug \
    && docker-php-source delete \
    && echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.remote_autostart=off" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.remote_port=9000" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.remote_handler=dbgp" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.remote_connect_back=0" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && rm -rf /tmp/* \
    #&& curl -L https://github.com/vishnubob/wait-for-it/raw/master/wait-for-it.sh > /tmp/wait-for-it.sh \
    #&& chmod +x /tmp/wait-for-it.sh
# Setup PHPUnit & Tests
WORKDIR /tmp
COPY ./ /tmp/wp-tests/
RUN wget https://phar.phpunit.de/phpunit-6.5.phar
    && chmod +x phpunit-6.5.phar
    && sudo mv phpunit-6.5.phar /usr/bin/phpunit
    && phpunit --version
RUN /tmp/install-wp-tests.sh test root test localhost $WP_VERSION
# Run PHP Tests
RUN phpcs --standard=WordPress ./**/*.php
RUN phpunit --coverage-clover=coverage.xml
RUN '! find . -type f -name "*.php" -exec php -d error_reporting=32767 -l {} \; 2>&1 >&- | grep "^"'