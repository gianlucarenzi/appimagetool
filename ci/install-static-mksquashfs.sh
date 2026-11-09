#! /bin/bash

set -euxo pipefail

if [[ "${1:-}" == "" ]]; then
    echo "Usage: $0 <version>"
    exit 2
fi

version="$1"

build_dir="$(mktemp -d -t mksquashfs-build-XXXXXX)"

cleanup () {
    if [ -d "$build_dir" ]; then
        rm -rf "$build_dir"
    fi
}
trap cleanup EXIT

pushd "$build_dir"

# downloaded by ci/download-with-gh.sh, if it ran
repo_root="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")"/..)"
if [[ -s "$repo_root"/downloads/squashfs-tools-"$version".tar.gz ]]; then
    tar xvzf "$repo_root"/downloads/squashfs-tools-"$version".tar.gz --strip-components=1
else
    wget https://github.com/plougher/squashfs-tools/archive/refs/tags/"$version".tar.gz -qO - | tar xvz --strip-components=1
fi

cd squashfs-tools

if [[ "${GITHUB_ACTIONS:-}" != "" ]]; then
    jobs="$(nproc)"
else
    jobs="$(nproc --ignore=1)"
fi

make -j"$jobs" GZIP_SUPPORT=0 XZ_SUPPORT=0 LZO_SUPPORT=0 LZ4_SUPPORT=0 ZSTD_SUPPORT=1 COMP_DEFAULT=zstd LDFLAGS=-static USE_PREBUILT_MANPAGES=y install
