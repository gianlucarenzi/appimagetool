#! /bin/bash

# Runs on the GitHub Actions runner, before the build container: downloads from GitHub
# what the build needs, with the GitHub CLI and the token of the workflow, into
# downloads/ in the repository (mounted in the container as /source/downloads).
# Authenticated requests do not suffer when GitHub throttles anonymous ones (e.g.
# "504 Gateway Time-out"); the build scripts use these files when they are there and
# fall back to downloading them with wget otherwise, so a failure here is not fatal.
#
# Usage: env ARCH=... [RUNTIME_URL_BASE=...] GH_TOKEN=... bash ci/download-with-gh.sh

set -uo pipefail

if [[ "${ARCH:-}" == "" ]]; then
    echo "Usage: env ARCH=... bash $0"
    exit 2
fi

repo_root="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")"/..)"
downloads="$repo_root"/downloads
mkdir -p "$downloads"

if ! command -v gh >/dev/null; then
    echo "gh not found: the build scripts will download with wget"
    exit 0
fi

# retry, as the API can time out as well
retry() {
    local i
    for i in 1 2 3 4 5; do
        "$@" && return 0
        echo "attempt $i failed: $*" >&2
        sleep $((i * 10))
    done
    return 1
}

# runtime-$ARCH: from RUNTIME_URL_BASE when it is a GitHub release download URL
# (https://github.com/<owner>/<repo>/releases/download/<tag>), else from the
# type2-runtime continuous release; another URL is left to wget in the build scripts
runtime_repo=AppImage/type2-runtime
runtime_tag=continuous
if [[ "${RUNTIME_URL_BASE:-}" != "" ]]; then
    if [[ "$RUNTIME_URL_BASE" =~ ^https://github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/?$ ]]; then
        runtime_repo="${BASH_REMATCH[1]}"
        runtime_tag="${BASH_REMATCH[2]}"
    else
        runtime_repo=""
    fi
fi
if [[ "$runtime_repo" != "" ]]; then
    retry gh release download "$runtime_tag" -R "$runtime_repo" -p runtime-"$ARCH" -D "$downloads" --clobber \
        || rm -f "$downloads"/runtime-"$ARCH"
fi

# the sources of squashfs-tools, in the version that ci/build-in-docker.sh builds
squashfs_version="$(grep -oE 'install-static-mksquashfs\.sh [^ ]+' "$repo_root"/ci/build-in-docker.sh | cut -d' ' -f2)"
if [[ "$squashfs_version" != "" ]]; then
    squashfs_tarball="$downloads"/squashfs-tools-"$squashfs_version".tar.gz
    retry sh -c 'gh api "repos/plougher/squashfs-tools/tarball/refs/tags/$1" > "$2" && gzip -t "$2"' \
        sh "$squashfs_version" "$squashfs_tarball" \
        || rm -f "$squashfs_tarball"
fi

ls -l "$downloads"
exit 0
