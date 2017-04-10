#!/bin/bash
set -e

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

# Get the most recent commit which modified any of "$@".
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# Get the most recent commit which modified "$1/Dockerfile" or any file that
# the Dockerfile copies into the rootfs (with COPY).
dockerfileCommit() {
	local dir="$1"; shift
	(
		cd "$dir";
		fileCommit Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++)
							print $i;
				}
			')
	)
}

# Header.
cat <<-EOH
# This file is generated via https://github.com/piwik/docker-piwik/blob/$(fileCommit "$self")/$self
Maintainers: Pierre Ozoux <pierre@piwik.org> (@pierreozoux)
GitRepo: https://github.com/piwik/docker-piwik.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

latest="$(
	git ls-remote --tags https://github.com/piwik/piwik.git \
		| cut -d/ -f3 \
		| grep -vE -- '-rc|-b' \
		| sort -V \
		| tail -1
)"

variants=( */ )
variants=( "${variants[@]%/}" )

for variant in "${variants[@]}"; do
	commit="$(dockerfileCommit "$variant")"
	fullversion="$(git show "$commit":"$variant/Dockerfile" | awk '$1 == "ENV" && $2 == "PIWIK_VERSION" { print $3; exit }')"

	versionAliases=( "$fullversion" "${fullversion%.*}" "${fullversion%.*.*}" )
	if [ "$fullversion" = "$latest" ]; then
		versionAliases+=( "latest" )
	fi

	variantAliases=( "${versionAliases[@]/%/-$variant}" )
	variantAliases=( "${variantAliases[@]//latest-}" )

	if [ "$variant" = "apache" ]; then
		variantAliases+=( "${versionAliases[@]}" )
	fi

	cat <<-EOE

		Tags: $(join ', ' "${variantAliases[@]}")
		GitCommit: $commit
		Directory: $variant
	EOE
done
