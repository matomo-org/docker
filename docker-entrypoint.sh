#!/bin/bash
set -e

if [ ! -e '/var/www/html/piwik.php' ]; then
	tar cf - --one-file-system -C /usr/src/piwik . | tar xf -
	chown -R www-data /var/www/html
fi

while /bin/true; do
  su -s "/bin/bash" -c "/usr/local/bin/php /var/www/html/console core:archive" www-data
  sleep 3600
done &

exec "$@"
