#!/bin/sh
set -e

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	local varValue=$(env | grep -E "^${var}=" | sed -E -e "s/^${var}=//")
	local fileVarValue=$(env | grep -E "^${fileVar}=" | sed -E -e "s/^${fileVar}=//")
	if [ -n "${varValue}" ] && [ -n "${fileVarValue}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	if [ -n "${varValue}" ]; then
		export "$var"="${varValue}"
	elif [ -n "${fileVarValue}" ]; then
		export "$var"="$(cat "${fileVarValue}")"
	elif [ -n "${def}" ]; then
		export "$var"="$def"
	fi
	unset "$fileVar"
}

# version_greater A B returns whether A > B
version_greater() {
	php -r 'exit(version_compare($argv[1], $argv[2], ">") ? 0 : 1);' "$1" "$2"
}

# manifest_files DIR lists the files of the Matomo release in DIR, according to its manifest
manifest_files() {
	php -r 'require $argv[1]; echo implode("\n", array_keys(\Piwik\Manifest::$files)), "\n";' "$1/config/manifest.inc.php"
}

run_as() {
	if [ "$(id -u)" = 0 ]; then
		su -p "$user" -s /bin/sh -c "$1"
	else
		sh -c "$1"
	fi
}

file_env 'MATOMO_DATABASE_HOST'
file_env 'MATOMO_DATABASE_USERNAME'
file_env 'MATOMO_DATABASE_PASSWORD'
file_env 'MATOMO_DATABASE_DBNAME'

uid="$(id -u)"
gid="$(id -g)"
if [ "$uid" = '0' ]; then
	case "$1" in
		apache2*)
			user="${APACHE_RUN_USER:-www-data}"
			group="${APACHE_RUN_GROUP:-www-data}"

			# strip off any '#' symbol ('#1000' is valid syntax for Apache)
			user="${user#'#'}"
			group="${group#'#'}"
			;;
		*) # php-fpm
			user='www-data'
			group='www-data'
			;;
	esac
else
	user="$uid"
	group="$gid"
fi

if [ ! -e matomo.php ]; then
	tar cf - --one-file-system -C /usr/src/matomo . | tar xf -
	chown -R "$user":"$group" .
fi

if [ "${MATOMO_AUTO_UPGRADE:-}" = '1' ] && [ -e config/config.ini.php ]; then
	(
		if ! flock -n 9; then
			echo "Another process is upgrading Matomo. Waiting..."
			flock 9
		fi

		installed_version="$(sed -n "s/.*const VERSION = '\([^']*\)'.*/\1/p" core/Version.php)"
		if version_greater "$installed_version" "$MATOMO_VERSION"; then
			echo >&2 "warning: not downgrading Matomo $installed_version to $MATOMO_VERSION"
			exit
		fi

		if version_greater "$MATOMO_VERSION" "$installed_version"; then
			echo "Upgrading Matomo from $installed_version to $MATOMO_VERSION ..."
			manifest_files . > /tmp/old-files || exit
			manifest_files /usr/src/matomo > /tmp/new-files || exit

			# Version.php and the manifest go last, so that the next start repeats a failed upgrade
			tar cf - --one-file-system -C /usr/src/matomo --exclude ./core/Version.php --exclude ./config/manifest.inc.php . | tar xf - || exit
			grep -vxFf /tmp/new-files /tmp/old-files | while read -r file; do
				# not every file of a release is in its manifest
				[ -e "/usr/src/matomo/$file" ] || rm -f "$file"
			done
			tar cf - -C /usr/src/matomo ./config/manifest.inc.php ./core/Version.php | tar xf - || exit
			chown -R "$user":"$group" .
		fi

		run_as 'php console core:update --yes' && run_as 'php console custom-matomo-js:update'
	) 9>> tmp/matomo-upgrade.lock || echo >&2 "error: upgrading Matomo failed, starting it anyway"
fi

exec "$@"
