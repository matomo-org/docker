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

# usage: matomo_version DIR
# (prints the version of the Matomo in DIR, read from core/Version.php without running it)
matomo_version() {
	sed -n "s/.*const VERSION = '\([^']*\)'.*/\1/p" "$1/core/Version.php" 2> /dev/null || true
}

# usage: version_greater A B
# (succeeds if version A is greater than version B)
version_greater() {
	php -r 'exit(version_compare($argv[1], $argv[2], ">") ? 0 : 1);' "$1" "$2"
}

# usage: run_as CMD
# (runs CMD as the user that Apache or PHP-FPM run as: APACHE_RUN_USER or www-data, or the user of the container if it
#  doesn't run as root. That's not necessarily the owner of the files, but everything CMD creates stays usable by them.)
run_as() {
	if [ "$uid" = '0' ]; then
		su -p "$user" -s /bin/sh -c "$1"
	else
		sh -c "$1"
	fi
}

# usage: lock_upgrade
# (takes the lock on file descriptor 9, waiting for as long as another container is upgrading Matomo)
lock_upgrade() {
	if ! flock -n 9; then
		echo >&2 "Another container is upgrading Matomo. Waiting..."
		flock 9
	fi
}

# usage: upgrade_matomo
# (MATOMO_AUTO_UPGRADE=1, see "Upgrading" in the README: brings the Matomo in the current directory to the version of
#  this image and upgrades its database. Never downgrades. A step that fails is logged and the container starts anyway,
#  so that Matomo asks for the upgrade like after a manual one; the next start tries again.)
upgrade_matomo() {
	image_version="$(matomo_version /usr/src/matomo)"
	installed_version="$(matomo_version .)"
	if [ -z "$installed_version" ] || [ -z "$image_version" ]; then
		echo >&2 "warning: not upgrading Matomo: can't read its version from $PWD/core/Version.php"
		return
	fi
	if version_greater "$installed_version" "$image_version"; then
		echo >&2 "warning: not upgrading Matomo: $installed_version in $PWD is newer than $image_version in this image (no downgrades)"
		return
	fi
	if ! run_as true; then
		echo >&2 "warning: not upgrading Matomo: can't run commands as $user"
		return
	fi

	# in tmp/, which Matomo's file integrity check ignores, and which all containers that use the volume share
	lock=tmp/matomo-upgrade.lock
	if ! run_as "mkdir -p tmp && : >> $lock"; then
		echo >&2 "warning: not upgrading Matomo: $user can't create $PWD/$lock"
		return
	fi

	(
		if ! lock_upgrade; then
			echo >&2 "warning: not upgrading Matomo: can't lock $PWD/$lock"
			exit
		fi

		# another container might have upgraded Matomo in the meantime, maybe even to a newer version
		installed_version="$(matomo_version .)"
		if version_greater "$installed_version" "$image_version"; then
			echo >&2 "warning: not upgrading Matomo: $installed_version in $PWD is newer than $image_version in this image (no downgrades)"
			exit
		fi

		if version_greater "$image_version" "$installed_version" && ! upgrade_code; then
			exit
		fi

		echo >&2 "Running the database upgrades of Matomo, if any ..."
		if ! run_as 'php console core:update --yes'; then
			echo >&2 "error: the database upgrade of Matomo failed; it will ask for it in the browser (or run: php console core:update)"
			exit
		fi
		if ! run_as 'php console custom-matomo-js:update'; then
			echo >&2 "error: Matomo couldn't update its JavaScript tracker (run: php console custom-matomo-js:update)"
		fi
	) 9>> "$lock"
}

# usage: upgrade_code
# (replaces the files of the Matomo release in the current directory by those of this image and deletes the files that
#  the new release no longer has; everything else, like config.ini.php or plugins from the Marketplace, stays)
upgrade_code() {
	# replacing a file needs write access to its directory
	unwritable="$(run_as '
		(cd /usr/src/matomo && find . -type d) | while IFS= read -r dir; do
			if [ -d "$dir" ] && [ ! -w "$dir" ]; then
				echo "  $dir"
			fi
		done
	')"
	if [ -n "$unwritable" ]; then
		echo >&2 "warning: not upgrading Matomo to $image_version: $user can't write to these directories in $PWD (and maybe more):"
		printf '%s\n' "$unwritable" | head -n 10 >&2
		return 1
	fi

	echo >&2 "Upgrading Matomo from $installed_version to $image_version ..."

	# exactly the files that the installed release has (according to its manifest) and the new one doesn't, as long as
	# they are unmodified; listed before the copy replaces the manifest. Both manifests declare the same class, hence
	# two PHP processes (and the old one, from the volume, doesn't run as root).
	if [ ! -f config/manifest.inc.php ]; then
		echo >&2 "warning: not upgrading Matomo: without $PWD/config/manifest.inc.php, the files that $image_version no longer has are unknown"
		return 1
	fi
	# (the PHP code goes into single quotes, so it must not contain any)
	list_files='
		require $argv[1];
		foreach (\Piwik\Manifest::$files as $file => $info) {
			echo $file, "\t", $info[0], "\t", $info[1], "\n";
		}
	'
	if ! old_files="$(run_as "php -r '$list_files' config/manifest.inc.php")"; then
		echo >&2 "error: not upgrading Matomo: can't read $PWD/config/manifest.inc.php"
		return 1
	fi
	list_obsolete_files='
		require $argv[1] . "/config/manifest.inc.php";
		while (($line = fgets(STDIN)) !== false) {
			$entry = explode("\t", rtrim($line, "\n"));
			if (count($entry) != 3) {
				continue;
			}
			list($file, $size, $hash) = $entry;
			if ($file === "" || $file[0] === "/" || strpos($file, "\0") !== false || in_array("..", explode("/", $file))) {
				continue;
			}
			// still in the release (not all of its files are in the manifest), or not there anyway
			if (isset(\Piwik\Manifest::$files[$file]) || file_exists($argv[1] . "/" . $file) || is_link($file) || !is_file($file)) {
				continue;
			}
			if ((string) filesize($file) !== $size || hash_file(strlen($hash) == 32 ? "md5" : "sha256", $file) !== $hash) {
				fwrite(STDERR, "warning: keeping $file: the new release no longer has it, but it was modified\n");
				continue;
			}
			echo $file, "\n";
		}
	'
	if ! obsolete="$(printf '%s\n' "$old_files" | run_as "php -r '$list_obsolete_files' /usr/src/matomo")"; then
		echo >&2 "error: not upgrading Matomo: can't compare the manifests of $installed_version and $image_version"
		return 1
	fi

	# all but the files that tell the version, so that the next start repeats a copy that fails
	if ! tar cf - --one-file-system -C /usr/src/matomo --anchored --exclude ./core/Version.php --exclude ./config/manifest.inc.php . \
		| run_as 'tar xf - --keep-directory-symlink --no-overwrite-dir'; then
		echo >&2 "error: copying the files of Matomo $image_version to $PWD failed; the next start of the container tries again"
		return 1
	fi

	if [ -n "$obsolete" ]; then
		echo >&2 "Deleting the files that Matomo $image_version no longer has:"
		if ! printf '%s\n' "$obsolete" | run_as '
			while IFS= read -r file; do
				echo "  $file"
				rm -f -- "$file" || exit
				# and the directories that only held such files
				dir="$file"
				while [ "${dir%/*}" != "$dir" ]; do
					dir="${dir%/*}"
					if [ -d "/usr/src/matomo/$dir" ] || ! rmdir -- "$dir" 2> /dev/null; then
						break
					fi
				done
			done
		' >&2; then
			echo >&2 "error: couldn't delete all of them; Matomo's system check lists the ones that are left"
		fi
	fi

	if ! tar cf - -C /usr/src/matomo ./config/manifest.inc.php ./core/Version.php \
		| run_as 'tar xf - --keep-directory-symlink --no-overwrite-dir'; then
		echo >&2 "error: copying the files of Matomo $image_version to $PWD failed; the next start of the container tries again"
		return 1
	fi
	echo >&2 "The files of Matomo are now those of $image_version"
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
	upgrade_matomo || echo >&2 "error: upgrading Matomo failed, starting it anyway"
fi

exec "$@"
