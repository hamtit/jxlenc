# jxlenc

Prebuilt [libjxl](https://github.com/libjxl/libjxl) packages, built by GitHub
Actions (`.github/workflows/build.yml`, Ubuntu 24.04 runners) from unmodified
upstream sources.

| Release asset | Contents |
| --- | --- |
| `libjxl-native-<ver>-<rev>.tgz` | shared libraries for Linux x64 and arm64 (cross-compiled) + headers ([README](packages/native/README.md)) |
| `libjxl-wasm-<ver>-<rev>.tgz` | WebAssembly modules, single-threaded and pthreads ([README](packages/wasm/README.md)) |

Both are npm package tarballs. They are not published to the npm registry;
install them from the release URL:

```sh
npm install https://github.com/hamtit/jxlenc/releases/download/v0.12.0-1/libjxl-native-0.12.0-1.tgz
npm install https://github.com/hamtit/jxlenc/releases/download/v0.12.0-1/libjxl-wasm-0.12.0-1.tgz
```

(`"private": true` is set in both packages so that they cannot be published by
accident.)

## Releasing

1. Edit `build.env`: `LIBJXL_VERSION`, `LIBJXL_COMMIT` (commit of the upstream
   tag, checked after cloning), `PACKAGE_REVISION` (start at 1, bump to
   re-release the same libjxl version), `EMSDK_VERSION`.
2. Merge, then push the tag `v<LIBJXL_VERSION>-<PACKAGE_REVISION>`:

   ```sh
   git tag v0.12.0-1 && git push origin v0.12.0-1
   ```

The workflow refuses tags that do not match `build.env`. Pull requests and
manual runs build and test everything and keep the packages as workflow
artifacts without releasing.

## Layout

```
build.env                 versions to build
scripts/fetch-libjxl.sh   clone libjxl + the submodules that get linked in
scripts/build-native.sh   CMake shared build (x64 native, arm64 cross)
scripts/build-wasm.sh     Emscripten static build + link to .js/.wasm
scripts/pack.mjs          assemble and `npm pack` the packages
packages/{native,wasm}/   package templates (package.json, README, JS)
tests/                    round-trip smoke tests (C and wasm)
```

## Licenses

The packages redistribute third-party code; every package includes the
license texts in `licenses/`:

- libjxl: BSD-3-Clause, plus the patent grant in `PATENTS`
- brotli: MIT
- highway: Apache-2.0 OR BSD-3-Clause
- skcms: BSD-3-Clause
- wasm only: Emscripten runtime (MIT OR NCSA), libc++/libc++abi/compiler-rt
  (Apache-2.0 WITH LLVM-exception), musl (MIT)

Only libraries under permissive licenses are linked in; optional
components with other licenses or extra dependencies (tools, jpegli/libjpeg-turbo,
sjpeg, lcms2, OpenEXR, gtest) are not built. These packages are unofficial
and not endorsed by the libjxl authors or Google.
