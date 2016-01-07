#!/bin/bash
set -e

url='git://github.com/piwik/docker-piwik.git'

commit="$(git log -1 --format='format:%H' -- Dockerfile $(awk 'toupper($1) == "COPY" { for (i = 2; i < NF; i++) { print $i } }' Dockerfile))"
fullVersion="$(grep -m1 'ENV PIWIK_VERSION ' ./Dockerfile | cut -d' ' -f3)"

echo '# maintainer pierre@piwik.org'
echo
echo "$fullVersion: ${url}@${commit}"
echo "${fullVersion%.*}: ${url}@${commit}"
echo "${fullVersion%.*.*}: ${url}@${commit}"
echo "latest: ${url}@${commit}"
