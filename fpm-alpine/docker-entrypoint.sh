#!/bin/sh
set -e

LOG_LEVEL=${LOG_LEVEL:-WARN}

if [ ! -s "/data/geoip" ]; then
    mkdir -p /data/geoip
fi

if [ ! -s "/data/config" ]; then
    mkdir -p /data/config
fi

chown -R www-data:www-data /data

if [ ! -e matomo.php ]; then
	cp -r /usr/src/matomo/* /var/www/html/
	chown -R www-data:www-data .
fi

cp -Rf /var/www/html/config /data/

if [ ! -s "/var/www/html/misc/DBIP-City.mmdb" ]; then
    mv /var/geoip/DBIP-City.mmdb /data/geoip/DBIP-City.mmdb
    ln -s /data/geoip/DBIP-City.mmdb /var/www/html/misc/DBIP-City.mmdb
fi

# Check if already installed
if [ -f /data/config/config.ini.php ]; then
    echo "Setting Matomo log level to $LOG_LEVEL..."
    su www-data -s /bin/sh -c "php /var/www/html/console config:set --section='log' --key='log_level' --value='$LOG_LEVEL'"

    echo "Upgrading and setting Matomo configuration..."
    su www-data -s /bin/sh -c "php /var/www/html/console core:update --yes --no-interaction"
    su www-data -s /bin/sh -c "php /var/www/html/console config:set --section='General' --key='minimum_memory_limit' --value='-1'"
else
    echo ">>"
    echo ">> Open your browser to install Matomo through the wizard"
    echo ">>"
fi

exec "$@"
