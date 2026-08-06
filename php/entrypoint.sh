#!/bin/sh
set -e

cd /var/www/html

if [ ! -d vendor ] || [ ! -f vendor/autoload.php ]; then
    composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction
fi

exec docker-php-entrypoint "$@"
