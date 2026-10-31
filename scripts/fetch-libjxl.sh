#!/usr/bin/env bash
# Fetch the libjxl sources (and only the submodules the library needs).
# Usage: fetch-libjxl.sh <dest-dir>
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../build.env
source "$here/build.env"

dest="${1:?dest dir}"
rm -rf "$dest"
git -c advice.detachedHead=false clone --quiet --depth 1 \
  --branch "v${LIBJXL_VERSION}" https://github.com/libjxl/libjxl.git "$dest"

actual="$(git -C "$dest" rev-parse HEAD)"
if [[ "$actual" != "$LIBJXL_COMMIT" ]]; then
  echo "libjxl v${LIBJXL_VERSION} resolved to $actual, expected $LIBJXL_COMMIT" >&2
  exit 1
fi

# brotli, highway and skcms are linked into the libraries we ship.
# Everything else (tests, tools, jpegli, sjpeg, ...) is not built.
git -C "$dest" submodule update --init --depth 1 \
  third_party/brotli third_party/highway third_party/skcms
