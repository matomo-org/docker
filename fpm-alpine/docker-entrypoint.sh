#!/bin/sh
set -e

if [ ! -e matomo.php ]; then
	tar cf - --one-file-system -C /usr/src/matomo . | tar xf -
    ln -s /usr/src/matomo/DBIP-City.mmdb /var/www/html/misc/DBIP-City.mmdb
	chown -R www-data:www-data .
fi

exec "$@"
