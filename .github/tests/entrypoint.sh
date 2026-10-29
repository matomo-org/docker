#!/bin/sh
# Tests the entrypoint of an image against an installation of the previous release of the same variant from Docker Hub:
#
#   1. bc          without MATOMO_AUTO_UPGRADE nothing in the volume changes
#   2. upgrade     MATOMO_AUTO_UPGRADE=1 upgrades the files and the database, keeps what isn't part of the release and
#                  deletes the files that the new release no longer has
#   3. downgrade   a volume with a newer Matomo stays as it is
#   4. parallel    two containers that start at the same time on the same volume upgrade it once
#   5. install     a fresh installation through the web installer works
#   6. permissions a container that doesn't run as root upgrades a volume it can write to; a volume that the user of
#                  Apache or PHP-FPM can't write to stays as it is
#   7. retry       a step that fails doesn't stop the container, and the next start repeats it
#
# usage: .github/tests/entrypoint.sh VARIANT IMAGE [TEST...]
#        (VARIANT: apache, fpm or fpm-alpine; IMAGE: built from VARIANT/; all tests by default)
# PREVIOUS_VERSION overrides the release to upgrade from (default: the latest one on Docker Hub before that of IMAGE).
set -eu
cd "$(dirname "$0")/../.."

variant="$1"
image="$2"
shift 2
tests="${*:-bc upgrade downgrade parallel install permissions retry}"

# (unique, so that tests of different variants can run at the same time)
prefix="matomo-test-$variant-$$"
db="$prefix-db"
work="$(mktemp -d)"

# usage: fail MESSAGE
fail() {
	echo >&2 "FAILED: $1"
	exit 1
}

# usage: step MESSAGE
step() {
	echo
	echo "=== $1"
}

cleanup() {
	docker ps -aq --filter "name=^$prefix-" | xargs docker rm -f > /dev/null 2>&1 || true
	docker volume ls -q --filter "name=^$prefix-" | xargs docker volume rm > /dev/null 2>&1 || true
	docker network rm "$prefix" > /dev/null 2>&1 || true
	rm -rf "$work"
}
trap cleanup EXIT

# usage: in_volume VOLUME USER SCRIPT
# (runs SCRIPT in a throwaway container of the image, in the volume)
in_volume() {
	docker run --rm --user "$2" --volume "$1:/var/www/html" --workdir /var/www/html --entrypoint sh "$image" -c "$3"
}

# usage: copy_volume FROM TO
copy_volume() {
	docker volume create "$2" > /dev/null
	docker run --rm --volume "$1:/from:ro" --volume "$2:/to" --entrypoint sh "$image" -c 'cp -a /from/. /to/'
}

# usage: snapshot VOLUME
# (prints path, type, owner, mode and checksum of everything in VOLUME but tmp/)
snapshot() {
	in_volume "$1" root '
		find . -path ./tmp -prune -o -exec stat -c "%n %F %u:%g %a" {} + | sort
		find . -path ./tmp -prune -o -type f -exec sha256sum {} + | sort -k 2
	'
}

wait_database() {
	for _ in $(seq 60); do
		[ "$(docker inspect -f '{{.State.Health.Status}}' "$db")" = 'healthy' ] && return
		sleep 1
	done
	fail "the database didn't start"
}

# usage: sql QUERY
sql() {
	docker exec "$db" mariadb -uroot -proot -N -e "$1" matomo
}

# (prints the version of Matomo that the database has)
database_version() {
	sql "SELECT option_value FROM matomo_option WHERE option_name = 'version_core'"
}

# usage: restore_database
# (resets the database to the installation of the previous release)
restore_database() {
	sql 'DROP DATABASE matomo; CREATE DATABASE matomo'
	docker exec -i "$db" mariadb -uroot -proot matomo < "$work/previous.sql"
}

# usage: start_matomo NAME VOLUME IMAGE [DOCKER RUN ARGS...]
start_matomo() {
	start_name="$1"
	start_volume="$2"
	start_image="$3"
	shift 3
	docker run --detach --name "$start_name" --network "$prefix" --volume "$start_volume:/var/www/html" \
		--env MATOMO_DATABASE_HOST=db --env MATOMO_DATABASE_USERNAME=matomo --env MATOMO_DATABASE_PASSWORD=matomo \
		--env MATOMO_DATABASE_DBNAME=matomo --env MATOMO_DATABASE_TABLES_PREFIX=matomo_ \
		"$@" "$start_image" > /dev/null
}

# usage: wait_ready NAME
# (waits until Apache or PHP-FPM runs in the container, after the entrypoint)
wait_ready() {
	for _ in $(seq 180); do
		if docker logs "$1" 2>&1 | grep -qE 'resuming normal operations|ready to handle connections'; then
			return
		fi
		if [ "$(docker inspect -f '{{.State.Running}}' "$1")" != 'true' ]; then
			docker logs "$1" >&2
			fail "$1 stopped"
		fi
		sleep 1
	done
	docker logs "$1" >&2
	fail "$1 didn't start"
}

# usage: start_web VOLUME IMAGE [DOCKER RUN ARGS...]
# (starts Matomo as it is reachable through a web browser, prints its URL)
start_web() {
	web_volume="$1"
	web_image="$2"
	shift 2
	if [ "$variant" = 'apache' ]; then
		start_matomo "$prefix-app" "$web_volume" "$web_image" --publish 127.0.0.1::80 "$@"
		wait_ready "$prefix-app"
		web="$prefix-app"
	else
		start_matomo "$prefix-app" "$web_volume" "$web_image" --network-alias app "$@"
		wait_ready "$prefix-app"
		docker run --detach --name "$prefix-web" --network "$prefix" --volume "$web_volume:/var/www/html:ro" \
			--volume "$PWD/.examples/nginx/matomo.conf:/etc/nginx/conf.d/default.conf:ro" \
			--publish 127.0.0.1::80 nginx:alpine-slim > /dev/null
		web="$prefix-web"
	fi
	url="http://$(docker port "$web" 80/tcp | head -n 1)"
	for _ in $(seq 60); do
		if curl -fsS -o /dev/null "$url/matomo.js" 2> /dev/null; then
			echo "$url"
			return
		fi
		sleep 1
	done
	fail "Matomo isn't reachable on $url"
}

stop_web() {
	docker rm -f "$prefix-app" "$prefix-web" > /dev/null 2>&1 || true
}

# usage: install URL
# (installs Matomo through its web installer)
install() {
	cookies="$work/cookies"
	rm -f "$cookies"
	request() {
		curl -fsS -o /dev/null -c "$cookies" -b "$cookies" "$@"
	}
	request "$1/"
	request "$1/index.php?action=systemCheck"
	request "$1/index.php?action=databaseSetup" \
		--data-urlencode host=db \
		--data-urlencode username=matomo \
		--data-urlencode password=matomo \
		--data-urlencode dbname=matomo \
		--data-urlencode tables_prefix=matomo_ \
		--data-urlencode 'adapter=PDO\MYSQL' \
		--data-urlencode schema=Mysql
	request "$1/index.php?action=tablesCreation&module=Installation"
	request "$1/index.php?action=setupSuperUser" \
		--data-urlencode login=admin \
		--data-urlencode 'password=test-Passw0rd' \
		--data-urlencode 'password_bis=test-Passw0rd' \
		--data-urlencode email=admin@example.org
	request "$1/index.php?action=firstWebsiteSetup" \
		--data-urlencode siteName=Example \
		--data-urlencode url=https://example.org \
		--data-urlencode timezone=UTC \
		--data-urlencode ecommerce=0
	request "$1/index.php?action=trackingCode&module=Installation&site_idSite=1&site_name=Example"
	request "$1/index.php?action=finished&module=Installation" \
		--data-urlencode setup_geoip2=0 \
		--data-urlencode anonymise_ip=1

	case "$(curl -fsS "$1/")" in
		*form_login*) ;;
		*) fail "Matomo doesn't show its login after the installation" ;;
	esac
}

# usage: matomo_version VOLUME
matomo_version() {
	in_volume "$1" root "sed -n \"s/.*const VERSION = '\\([^']*\\)'.*/\\1/p\" core/Version.php"
}

# usage: logs_of NAME
logs_of() {
	docker logs "$1" 2>&1
}

version="$(docker run --rm --entrypoint printenv "$image" MATOMO_VERSION)"
if [ -z "${PREVIOUS_VERSION:-}" ]; then
	# Docker Hub doesn't have every release
	for candidate in $(
		git ls-remote --tags https://github.com/matomo-org/matomo.git | cut -d/ -f3 \
			| grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -rV | awk -v current="$version" 'found { print } $0 == current { found = 1 }'
	); do
		if docker manifest inspect "matomo:$candidate-$variant" > /dev/null 2>&1; then
			PREVIOUS_VERSION="$candidate"
			break
		fi
	done
fi
[ -n "${PREVIOUS_VERSION:-}" ] || fail "no previous release of $version on Docker Hub"
previous="matomo:$PREVIOUS_VERSION-$variant"
echo "Testing $image ($version) against $previous"

step "Preparing an installation of $PREVIOUS_VERSION"
docker network create "$prefix" > /dev/null
docker run --detach --name "$db" --network "$prefix" --network-alias db \
	--env MARIADB_ROOT_PASSWORD=root --env MARIADB_DATABASE=matomo --env MARIADB_USER=matomo --env MARIADB_PASSWORD=matomo \
	--health-cmd 'healthcheck.sh --connect --innodb_initialized' --health-interval 2s \
	mariadb:lts --max-allowed-packet=64MB > /dev/null
wait_database

docker volume create "$prefix-previous" > /dev/null
url="$(start_web "$prefix-previous" "$previous")"
install "$url"
stop_web
docker exec "$db" mariadb-dump -uroot -proot matomo > "$work/previous.sql"

# what users add to an installation, and what an upgrade has to delete
in_volume "$prefix-previous" www-data '
	set -e
	mkdir -p plugins/DummyMarketplacePlugin misc/user core/ObsoleteDirectoryForTest
	echo "{\"name\": \"DummyMarketplacePlugin\", \"version\": \"1.0.0\"}" > plugins/DummyMarketplacePlugin/plugin.json
	echo "<?php namespace Piwik\Plugins\DummyMarketplacePlugin; class DummyMarketplacePlugin extends \Piwik\Plugin {}" \
		> plugins/DummyMarketplacePlugin/DummyMarketplacePlugin.php
	echo "<svg xmlns=\"http://www.w3.org/2000/svg\"/>" > misc/user/logo.svg
	echo "/* container */" > js/container_abcdefgh.js
	echo "not a real database" > misc/DBIP-City.mmdb
	echo "own file" > own-file.txt

	echo "<?php // removed from the release" > core/ObsoleteFileForTest.php
	echo "<?php // removed from the release" > core/ObsoleteDirectoryForTest/File.php
	echo "<?php // removed from the release, but modified" > core/ModifiedObsoleteFileForTest.php
	hash_length="$(sed -n "s/.*=> array(\"[0-9]*\", \"\([0-9a-f]*\)\"),$/\1/p" config/manifest.inc.php | head -n 1 | tr -d "\n" | wc -c)"
	for file in core/ObsoleteFileForTest.php core/ObsoleteDirectoryForTest/File.php core/ModifiedObsoleteFileForTest.php; do
		size="$(wc -c < "$file" | tr -d " ")"
		if [ "$hash_length" = 32 ]; then
			hash="$(md5sum < "$file" | cut -d " " -f 1)"
		else
			hash="$(sha256sum < "$file" | cut -d " " -f 1)"
		fi
		if [ "$file" = core/ModifiedObsoleteFileForTest.php ]; then
			hash="$(echo "$hash" | tr 0-9a-f 1-9a-f0)"
		fi
		awk -v entry="\t\t\"$file\" => array(\"$size\", \"$hash\")," "{ print } /static \\\$files=array\\(/ { print entry }" \
			config/manifest.inc.php > /tmp/manifest
		cat /tmp/manifest > config/manifest.inc.php
	done
	grep -c ForTest config/manifest.inc.php
'

for test in $tests; do
	volume="$prefix-$test"
	case "$test" in
		bc)
			step "1. without MATOMO_AUTO_UPGRADE nothing in the volume changes"
			copy_volume "$prefix-previous" "$volume"
			restore_database
			snapshot "$volume" > "$work/before"
			start_matomo "$prefix-bc" "$volume" "$image"
			wait_ready "$prefix-bc"
			logs_of "$prefix-bc"
			docker rm -f "$prefix-bc" > /dev/null
			snapshot "$volume" > "$work/after"
			diff "$work/before" "$work/after" || fail "the volume changed"
			[ "$(matomo_version "$volume")" = "$PREVIOUS_VERSION" ] || fail "the version changed"
			[ "$(database_version)" = "$PREVIOUS_VERSION" ] || fail "the database changed"
			;;

		upgrade)
			step "2. MATOMO_AUTO_UPGRADE=1 upgrades Matomo and keeps what isn't part of the release"
			copy_volume "$prefix-previous" "$volume"
			restore_database
			kept='config/config.ini.php plugins/DummyMarketplacePlugin/plugin.json plugins/DummyMarketplacePlugin/DummyMarketplacePlugin.php misc/user/logo.svg js/container_abcdefgh.js misc/DBIP-City.mmdb own-file.txt core/ModifiedObsoleteFileForTest.php'
			in_volume "$volume" root "sha256sum $kept" > "$work/kept"
			[ "$(database_version)" = "$PREVIOUS_VERSION" ] || fail "the database isn't that of $PREVIOUS_VERSION"
			start_matomo "$prefix-upgrade" "$volume" "$image" --env MATOMO_AUTO_UPGRADE=1
			wait_ready "$prefix-upgrade"
			logs_of "$prefix-upgrade"

			[ "$(matomo_version "$volume")" = "$version" ] || fail "the files weren't upgraded"
			[ "$(database_version)" = "$version" ] || fail "the database wasn't upgraded"
			docker run --rm --volume "$volume:/var/www/html:ro" --volume "$work:/work:ro" --workdir /var/www/html \
				--entrypoint sha256sum "$image" -c /work/kept || fail "files that aren't part of the release changed"
			# matomo.js and piwik.js get the tracker code of plugins
			docker exec "$prefix-upgrade" sh -c '
				cd /usr/src/matomo && find . -type f ! -name matomo.js ! -name piwik.js -exec sha256sum {} + > /tmp/release
				cd /var/www/html && ! sha256sum -c /tmp/release | grep -v ": OK$"
			' || fail "the files of the release differ from the image"
			in_volume "$volume" root '! find . -path ./tmp -prune -o ! -user www-data -print | grep .' \
				|| fail "files don't belong to www-data"
			in_volume "$volume" root '[ ! -e core/ObsoleteFileForTest.php ] && [ ! -e core/ObsoleteDirectoryForTest ]' \
				|| fail "the files that the new release no longer has are still there"
			logs_of "$prefix-upgrade" | grep -q 'warning: keeping core/ModifiedObsoleteFileForTest.php' \
				|| fail "no warning about the modified file"
			# Matomo agrees: nothing of the previous release is left, only files that it doesn't know were added above
			unexpected="$(docker exec --user www-data "$prefix-upgrade" php console diagnostics:unexpected-files \
				| sed -n 's|^/var/www/html/||p' | sort)"
			expected="$(printf '%s\n' core/ModifiedObsoleteFileForTest.php js/container_abcdefgh.js own-file.txt)"
			[ "$unexpected" = "$expected" ] || fail "Matomo reports other unexpected files than expected: $unexpected"

			docker rm -f "$prefix-upgrade" > /dev/null

			# the next start leaves the files alone
			snapshot "$volume" > "$work/before"
			start_matomo "$prefix-upgrade-again" "$volume" "$image" --env MATOMO_AUTO_UPGRADE=1
			wait_ready "$prefix-upgrade-again"
			logs_of "$prefix-upgrade-again"
			docker rm -f "$prefix-upgrade-again" > /dev/null
			snapshot "$volume" > "$work/after"
			diff "$work/before" "$work/after" || fail "the volume changed at the next start"
			;;

		downgrade)
			step "3. a volume with a newer Matomo stays as it is"
			copy_volume "$prefix-previous" "$volume"
			in_volume "$volume" www-data "sed -i \"s/const VERSION = '[^']*'/const VERSION = '99.0.0'/\" core/Version.php"
			snapshot "$volume" > "$work/before"
			start_matomo "$prefix-downgrade" "$volume" "$image" --env MATOMO_AUTO_UPGRADE=1
			wait_ready "$prefix-downgrade"
			logs_of "$prefix-downgrade"
			logs_of "$prefix-downgrade" | grep -q "warning: not upgrading Matomo: 99.0.0 .* is newer than $version" \
				|| fail "no warning about the newer version"
			docker rm -f "$prefix-downgrade" > /dev/null
			snapshot "$volume" > "$work/after"
			diff "$work/before" "$work/after" || fail "the volume changed"
			in_volume "$volume" root '[ ! -e tmp/matomo-upgrade.lock ]' || fail "the entrypoint took the lock"
			;;

		parallel)
			step "4. two containers that start at the same time upgrade Matomo once"
			copy_volume "$prefix-previous" "$volume"
			restore_database
			start_matomo "$prefix-parallel-1" "$volume" "$image" --env MATOMO_AUTO_UPGRADE=1 &
			start_matomo "$prefix-parallel-2" "$volume" "$image" --env MATOMO_AUTO_UPGRADE=1 &
			wait
			wait_ready "$prefix-parallel-1"
			wait_ready "$prefix-parallel-2"
			logs_of "$prefix-parallel-1"
			logs_of "$prefix-parallel-2"
			upgrades="$( (logs_of "$prefix-parallel-1"; logs_of "$prefix-parallel-2") | grep -c "^Upgrading Matomo from $PREVIOUS_VERSION to $version")"
			[ "$upgrades" = 1 ] || fail "$upgrades containers upgraded Matomo"
			[ "$(matomo_version "$volume")" = "$version" ] || fail "the files weren't upgraded"
			[ "$(database_version)" = "$version" ] || fail "the database wasn't upgraded"
			docker rm -f "$prefix-parallel-1" "$prefix-parallel-2" > /dev/null
			;;

		install)
			step "5. a fresh installation through the web installer works (with MATOMO_AUTO_UPGRADE=1)"
			sql 'DROP DATABASE matomo; CREATE DATABASE matomo'
			docker volume create "$volume" > /dev/null
			url="$(start_web "$volume" "$image" --env MATOMO_AUTO_UPGRADE=1)"
			in_volume "$volume" root '[ ! -e config/config.ini.php ] && [ ! -e tmp/matomo-upgrade.lock ]' \
				|| fail "the entrypoint did more than to copy Matomo"
			install "$url"
			logs_of "$prefix-app" | grep -q 'Matomo from' && fail "the entrypoint upgraded a fresh installation"
			stop_web
			;;

		permissions)
			step "6. a container that doesn't run as root upgrades a volume it can write to"
			copy_volume "$prefix-previous" "$volume"
			restore_database
			start_matomo "$prefix-non-root" "$volume" "$image" --env MATOMO_AUTO_UPGRADE=1 --user www-data
			wait_ready "$prefix-non-root"
			logs_of "$prefix-non-root"
			[ "$(matomo_version "$volume")" = "$version" ] || fail "the files weren't upgraded"
			[ "$(database_version)" = "$version" ] || fail "the database wasn't upgraded"
			docker rm -f "$prefix-non-root" > /dev/null

			step "6. ... and leaves a volume alone that it can't write to"
			copy_volume "$prefix-previous" "$volume-read-only"
			restore_database
			snapshot "$volume-read-only" > "$work/before"
			start_matomo "$prefix-read-only" "$volume-read-only" "$image" --env MATOMO_AUTO_UPGRADE=1 --user 12345:12345
			wait_ready "$prefix-read-only"
			logs_of "$prefix-read-only"
			logs_of "$prefix-read-only" | grep -q 'warning: not upgrading Matomo' || fail "no warning"
			docker rm -f "$prefix-read-only" > /dev/null
			snapshot "$volume-read-only" > "$work/after"
			diff "$work/before" "$work/after" || fail "the volume changed"

			step "6. ... like a container that runs as root, when www-data can't write to a directory of the release"
			copy_volume "$prefix-previous" "$volume-root-owned"
			in_volume "$volume-root-owned" root 'chown root:root core/Tracker'
			snapshot "$volume-root-owned" > "$work/before"
			start_matomo "$prefix-root-owned" "$volume-root-owned" "$image" --env MATOMO_AUTO_UPGRADE=1
			wait_ready "$prefix-root-owned"
			logs_of "$prefix-root-owned"
			logs_of "$prefix-root-owned" | grep -q "warning: not upgrading Matomo to $version: www-data can't write" \
				|| fail "no warning"
			logs_of "$prefix-root-owned" | grep -qx '  ./core/Tracker' || fail "the warning doesn't name the directory"
			docker rm -f "$prefix-root-owned" > /dev/null
			snapshot "$volume-root-owned" > "$work/after"
			diff "$work/before" "$work/after" || fail "the volume changed"
			;;

		retry)
			step "7. a step that fails doesn't stop the container, and the next start repeats it"
			copy_volume "$prefix-previous" "$volume"
			restore_database
			docker stop "$db" > /dev/null
			start_matomo "$prefix-retry" "$volume" "$image" --env MATOMO_AUTO_UPGRADE=1
			wait_ready "$prefix-retry"
			logs_of "$prefix-retry"
			logs_of "$prefix-retry" | grep -q 'error: the database upgrade of Matomo failed' || fail "no error about the database"
			docker rm -f "$prefix-retry" > /dev/null
			[ "$(matomo_version "$volume")" = "$version" ] || fail "the files weren't upgraded"

			docker start "$db" > /dev/null
			wait_database
			[ "$(database_version)" = "$PREVIOUS_VERSION" ] || fail "the database isn't that of $PREVIOUS_VERSION"
			start_matomo "$prefix-retry-again" "$volume" "$image" --env MATOMO_AUTO_UPGRADE=1
			wait_ready "$prefix-retry-again"
			logs_of "$prefix-retry-again"
			[ "$(database_version)" = "$version" ] || fail "the database wasn't upgraded at the next start"
			docker rm -f "$prefix-retry-again" > /dev/null
			;;

		*)
			fail "unknown test $test"
			;;
	esac
	echo "--- passed: $test"
done

echo
echo "All tests passed ($tests)"
