#!/bin/bash
set -e

cd /var/www/html

if [ ! -e piwik.php ]; then
	cp -ax /usr/src/piwik/* .
    if [ "$(id -u)" -eq 0 ]; then
        chown -R www-data .
    fi
fi

exec "$@"
