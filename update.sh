#!/bin/bash
set -e

declare -A cmd=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
)

declare -A base=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
)

latest="$(
	git ls-remote --tags https://github.com/matomo-org/matomo.git \
		| cut -d/ -f3 \
		| grep -vE -- '-rc|-a|-b' \
		| sort -V \
		| tail -1
)"

set -x

for variant in apache fpm fpm-alpine; do
	template="Dockerfile-${base[$variant]}.template"
	cp $template "$variant/Dockerfile"
	cp docker-entrypoint.sh "$variant/docker-entrypoint.sh"
	cp common.config.ini.php "$variant/common.config.ini.php"
	cp php.ini "$variant/php.ini"
	sed -ri -e '
		s/%%VARIANT%%/'"$variant"'/;
		s/%%VERSION%%/'"$latest"'/;
		s/%%CMD%%/'"${cmd[$variant]}"'/;
	' "$variant/Dockerfile"
done
