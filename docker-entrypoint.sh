#!/bin/bash
set -e

if [ ! -e '/var/www/html/piwik.php' ]; then
	tar cf - --one-file-system -C /usr/src/piwik . | tar xf -
	chown -R www-data /var/www/html
fi

exec "$@"
