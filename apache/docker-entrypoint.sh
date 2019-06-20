#!/bin/sh
set -e

if [ ! -e matomo.php ]; then
	tar cf - --one-file-system -C /usr/src/matomo . | tar xf -
	chown -R www-data .
fi

exec "$@"
