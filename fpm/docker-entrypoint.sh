#!/bin/sh
set -e

if [ ! -e matomo.php ]; then
	tar cf - --one-file-system -C /usr/src/matomo . | tar xf -
    if [ "$(id -u)" -eq 0 ]; then
        chown -R www-data .
    fi
fi

exec "$@"
