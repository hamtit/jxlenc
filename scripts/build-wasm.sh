#!/usr/bin/env bash
# Build libjxl as WebAssembly modules (Emscripten must be on PATH).
# Usage: build-wasm.sh <libjxl-src> <out-dir>
#
# <out-dir> receives:
#   dist/libjxl.{js,wasm}      single-threaded, SIMD128
#   dist/libjxl-mt.{js,wasm}   pthreads (needs SharedArrayBuffer), SIMD128
#   dist/*.exports             exported C symbols, one per line
#   include/                   public headers (jxl/ only)
#   licenses/                  license files of everything linked in
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
src="$(realpath "${1:?libjxl src}")"
out="$(realpath -m "${2:?out dir}")"
work="$(realpath -m "${WORK_DIR:-work}")/wasm"

rm -rf "$work" "$out"
mkdir -p "$out/dist" "$out/include" "$out/licenses"

build_variant() {
  local name="$1" threads="$2"
  local build="$work/build-$name" prefix="$work/prefix-$name"
  local cflags="-msimd128"
  [[ "$threads" == ON ]] && cflags+=" -pthread"

  emcmake cmake -S "$src" -B "$build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_C_FLAGS="$cflags" \
    -DCMAKE_CXX_FLAGS="$cflags" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DJPEGXL_ENABLE_WASM_THREADS="$threads" \
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
    -DJPEGXL_ENABLE_VIEWERS=OFF
  cmake --build "$build"
  cmake --install "$build"

  local lib="$prefix/lib"
  local libs=("$lib/libjxl.a" "$lib/libjxl_cms.a")
  local defs=()
  if [[ "$threads" == ON ]]; then
    libs+=("$lib/libjxl_threads.a")
    defs+=(-DJXLWASM_THREADS)
  fi
  # Exported API = every public C symbol (Jxl*) defined in the libjxl
  # archives; C++ internals are mangled and brotli/hwy use other prefixes.
  local exports="$out/dist/$name.exports"
  emnm --defined-only --extern-only "${libs[@]}" 2>/dev/null \
    | awk '$2 == "T" && $3 ~ /^Jxl/ { print $3 }' | sort -u > "$exports"
  grep -qx JxlEncoderCreate "$exports"
  grep -qx JxlDecoderCreate "$exports"
  local funcs
  funcs="$(sed 's/^/_/' "$exports" | paste -sd, -),_malloc,_free"

  # Dependencies after the libjxl archives (static link order matters).
  local brotli=()
  for b in brotlienc brotlidec brotlicommon; do
    brotli+=("$(ls "$lib"/lib${b}*.a | head -n1)")
  done

  local link=(
    -O3 -msimd128
    -sMODULARIZE=1
    -sEXPORT_ES6=1
    -sEXPORT_NAME=createLibjxl
    -sENVIRONMENT=web,worker,node
    -sFILESYSTEM=0
    -sALLOW_MEMORY_GROWTH=1
    -sMAXIMUM_MEMORY=4GB
    -sALLOW_TABLE_GROWTH=1
    -sSTACK_SIZE=1MB
    -sEXPORTED_FUNCTIONS="$funcs"
    -sEXPORTED_RUNTIME_METHODS=HEAP8,HEAPU8,HEAP16,HEAPU16,HEAP32,HEAPU32,HEAPF32,HEAPF64,getValue,setValue,UTF8ToString,stringToUTF8,lengthBytesUTF8,addFunction,removeFunction
  )
  if [[ "$threads" == ON ]]; then
    link+=(
      -pthread
      -sDEFAULT_PTHREAD_STACK_SIZE=1MB
      # Pre-spawn one worker per core so that JxlThreadParallelRunnerCreate
      # with JxlThreadParallelRunnerDefaultNumWorkerThreads() does not block.
      "-sPTHREAD_POOL_SIZE=globalThis.navigator?.hardwareConcurrency||4"
    )
  fi

  emcc "${link[@]}" "${defs[@]}" -I"$prefix/include" \
    "$here/packages/wasm/src/jxlwasm.c" \
    "${libs[@]}" "${brotli[@]}" "$lib/libhwy.a" \
    -o "$out/dist/$name.js"

  # The helper functions are part of the export surface too.
  grep -o 'jxlwasm_[a-z_]*(' "$here/packages/wasm/src/jxlwasm.c" \
    | tr -d '(' | sort -u >> "$exports"
  if [[ "$threads" != ON ]]; then
    sed -i '/parallel_runner$/d' "$exports"
  fi

  if [[ -z "$(ls -A "$out/include")" ]]; then
    cp -r "$prefix/include/jxl" "$out/include/"
    cp "$src/PATENTS" "$out/licenses/PATENTS.jpeg-xl"
    cp "$src/third_party/highway/LICENSE-BSD3" "$out/licenses/LICENSE-BSD3.highway"
    cp "$build"/LICENSE.* "$out/licenses/"
  fi
}

build_variant libjxl OFF
build_variant libjxl-mt ON

# Emscripten links its own runtime and system libraries into the output.
em_root="$(em-config EMSCRIPTEN_ROOT)"
cp "$em_root/LICENSE" "$out/licenses/LICENSE.emscripten"
cp "$em_root/system/lib/libcxx/LICENSE.TXT" "$out/licenses/LICENSE.libcxx"
cp "$em_root/system/lib/libcxxabi/LICENSE.TXT" "$out/licenses/LICENSE.libcxxabi"
cp "$em_root/system/lib/compiler-rt/LICENSE.TXT" "$out/licenses/LICENSE.compiler-rt"
cp "$em_root/system/lib/libc/musl/COPYRIGHT" "$out/licenses/LICENSE.musl"

ls -l "$out/dist" "$out/licenses"
wc -l "$out"/dist/*.exports
