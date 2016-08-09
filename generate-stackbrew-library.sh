#!/bin/bash
set -e

url='https://github.com/piwik/docker-piwik.git'

commit="$(git log -1 --format='format:%H' -- Dockerfile $(awk 'toupper($1) == "COPY" { for (i = 2; i < NF; i++) { print $i } }' Dockerfile))"
fullVersion="$(grep -m1 'ENV PIWIK_VERSION ' ./Dockerfile | cut -d' ' -f3)"

cat <<EOF
Maintainers: Pierre Ozoux <pierre@piwik.org> (@pierreozoux)
GitRepo: $url

Tags: $fullVersion, ${fullVersion%.*}, ${fullVersion%.*.*}, latest
GitCommit: $commit
EOF
