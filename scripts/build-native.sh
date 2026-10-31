#!/usr/bin/env bash
# Build the libjxl shared libraries for Linux.
# Usage: build-native.sh <libjxl-src> <x64|arm64> <out-dir>
#
# <out-dir> receives:
#   lib/        shared libraries, named by SONAME (no symlinks; npm drops them)
#   include/    public headers (jxl/ only)
#   licenses/   license files of everything linked into lib/
#
# With USE_CCACHE=1, compiles go through ccache.
set -euo pipefail
src="$(realpath "${1:?libjxl src}")"
arch="${2:?arch}"
out="$(realpath -m "${3:?out dir}")"
work="$(realpath -m "${WORK_DIR:-work}")/native-$arch"

# Cross-compile only when the runner's architecture differs from the target
# (arm64 normally builds natively on an arm64 runner).
case "$(uname -m)" in
  x86_64) host=x64 ;;
  aarch64) host=arm64 ;;
  *) host="$(uname -m)" ;;
esac

cmake_args=()
if [[ "${USE_CCACHE:-}" == 1 ]]; then
  cmake_args+=(-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
fi
case "$arch" in
  "$host") ;;
  arm64)
    cmake_args+=(
      -DCMAKE_SYSTEM_NAME=Linux
      -DCMAKE_SYSTEM_PROCESSOR=aarch64
      -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc
      -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++
      -DCMAKE_FIND_ROOT_PATH=/usr/aarch64-linux-gnu
      -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
      -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
    )
    ;;
  *) echo "unknown arch: $arch" >&2; exit 1 ;;
esac

rm -rf "$work" "$out"
cmake -S "$src" -B "$work/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$work/prefix" \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_TESTING=OFF \
  -DJPEGXL_ENABLE_TOOLS=OFF \
  -DJPEGXL_ENABLE_JPEGLI=OFF \
  -DJPEGXL_ENABLE_SJPEG=OFF \
  -DJPEGXL_ENABLE_OPENEXR=OFF \
  -DJPEGXL_ENABLE_SKCMS=ON \
  -DJPEGXL_ENABLE_DOXYGEN=OFF \
  -DJPEGXL_ENABLE_MANPAGES=OFF \
  -DJPEGXL_ENABLE_BENCHMARK=OFF \
  -DJPEGXL_ENABLE_EXAMPLES=OFF \
  -DJPEGXL_ENABLE_JNI=OFF \
  -DJPEGXL_ENABLE_FUZZERS=OFF \
  -DJPEGXL_ENABLE_DEVTOOLS=OFF \
  -DJPEGXL_ENABLE_PLUGINS=OFF \
  -DJPEGXL_ENABLE_VIEWERS=OFF \
  "${cmake_args[@]}"
cmake --build "$work/build"
cmake --install "$work/build" --strip

mkdir -p "$out/lib" "$out/include" "$out/licenses"
# Copy each real library under its SONAME, which is what the dynamic loader
# looks for (libjxl.so -> libjxl_cms.so.0.12 etc. via RUNPATH=$ORIGIN).
for f in "$work"/prefix/lib/lib*.so.*; do
  [[ -L "$f" ]] && continue
  soname="$(readelf -d "$f" | sed -n 's/.*Library soname: \[\(.*\)\]/\1/p')"
  cp "$f" "$out/lib/$soname"
done
# Development names (libjxl.so etc.) as GNU ld scripts instead of symlinks,
# so that `-L<lib> -ljxl` works without duplicating the binaries.
for f in "$out"/lib/lib*.so.*; do
  base="$(basename "$f")"
  echo "INPUT($base)" > "$out/lib/${base%%.so.*}.so"
done
cp -r "$work/prefix/include/jxl" "$out/include/"

cp "$src/PATENTS" "$out/licenses/PATENTS.jpeg-xl"
# highway is dual licensed; LICENSE.highway below is the Apache-2.0 text.
cp "$src/third_party/highway/LICENSE-BSD3" "$out/licenses/LICENSE-BSD3.highway"
for f in "$work"/build/LICENSE.*; do
  cp "$f" "$out/licenses/"
done

echo "== $arch"
ls -l "$out/lib"
for f in "$out"/lib/*.so.*; do
  echo "-- $(basename "$f")"
  readelf -d "$f" | grep -E 'NEEDED|SONAME|RUNPATH'
done
