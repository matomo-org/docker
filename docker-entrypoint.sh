#!/bin/sh
set -e

if [ ! -e "$APACHE_DOCUMENT_ROOT/config/global.ini.php" ]; then
  ln -s /usr/src/config/* "$APACHE_DOCUMENT_ROOT/config"
fi

if [ ! \( -n "$(ls -A "$APACHE_DOCUMENT_ROOT/plugins")" \) ]; then
  ln -s /usr/src/plugins/* "$APACHE_DOCUMENT_ROOT/plugins"
fi

exec "$@"
