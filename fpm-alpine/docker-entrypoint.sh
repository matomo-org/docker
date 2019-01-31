#!/bin/sh
set -e

if [ ! -e piwik.php ]; then
	tar cf - --one-file-system -C /usr/src/piwik . | tar xf -
fi

chown -R www-data .

exec "$@"
