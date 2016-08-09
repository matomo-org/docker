#!/bin/bash
set -e

latest="$(
	git ls-remote --tags https://github.com/piwik/piwik.git \
		| cut -d/ -f3 \
		| grep -vE -- '-rc|-b' \
		| sort -V \
		| tail -1
)"

set -x
sed -ri 's/^(ENV PIWIK_VERSION) .*/\1 '"$latest"'/' Dockerfile
