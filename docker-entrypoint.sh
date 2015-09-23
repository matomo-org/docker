#!/bin/bash
set -e

if [ ! -e '/var/www/html/piwik.php' ]; then
	tar cf - --one-file-system -C /usr/src/piwik . | tar xf -
	chown -R www-data /var/www/html
fi

chfn -f 'Piwik Admin' www-data

cat > /etc/ssmtp/ssmtp.conf << EOF
UseTLS=Yes
UseSTARTTLS=Yes
root=${MAIL_USER}
mailhub=${MAIL_HOST}:${MAIL_PORT}
hostname=${MAIL_USER}
AuthUser=${MAIL_USER}
AuthPass=${MAIL_PASS}
EOF

echo "www-data:${MAIL_USER}:${MAIL_HOST}:${MAIL_PORT}" >> /etc/ssmtp/revaliases

exec "$@"
