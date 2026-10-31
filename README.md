# jxlenc

Prebuilt [libjxl](https://github.com/libjxl/libjxl) packages, built by GitHub
Actions (`.github/workflows/build.yml`, Ubuntu 24.04 runners) from unmodified
upstream sources.

| Release asset | Contents |
| --- | --- |
| `libjxl-native-<ver>-<rev>.tgz` | shared libraries for Linux x64 and arm64 + headers ([README](packages/native/README.md)) |
| `libjxl-native-linux-x64-<ver>-<rev>.tgz`, `libjxl-native-linux-arm64-<ver>-<rev>.tgz` | the same, one architecture per package (`os`/`cpu` set, so package managers skip the other; [README](packages/native-arch/README.md)) |
| `libjxl-wasm-<ver>-<rev>.tgz` | WebAssembly modules, single-threaded and pthreads ([README](packages/wasm/README.md)) |

Both are npm package tarballs. They are not published to the npm registry;
install them from the release URL:

```sh
npm install https://github.com/hamtit/jxlenc/releases/download/v0.12.0-2/libjxl-native-0.12.0-2.tgz
npm install https://github.com/hamtit/jxlenc/releases/download/v0.12.0-2/libjxl-wasm-0.12.0-2.tgz
```

To fetch only the matching architecture, list both single-platform packages
as `optionalDependencies` (they have the same API as `libjxl-native`):

```json
"optionalDependencies": {
  "libjxl-native-linux-x64": "https://github.com/hamtit/jxlenc/releases/download/v0.12.0-2/libjxl-native-linux-x64-0.12.0-2.tgz",
  "libjxl-native-linux-arm64": "https://github.com/hamtit/jxlenc/releases/download/v0.12.0-2/libjxl-native-linux-arm64-0.12.0-2.tgz"
}
```

(`"private": true` is set in both packages so that they cannot be published by
accident.)

## Releasing

1. In a pull request, edit `build.env`: `LIBJXL_VERSION`, `LIBJXL_COMMIT`
   (commit of the upstream tag, checked after cloning), `PACKAGE_REVISION`
   (start at 1, bump to re-release the same libjxl version), `EMSDK_VERSION`.
2. Merge it. The build on `main` notices that the tag
   `v<LIBJXL_VERSION>-<PACKAGE_REVISION>` does not exist yet, builds without
   ccache, and after all tests pass creates the tag and the GitHub release.

Pushes to `main` whose tag already exists only build and test. Pushing a
matching tag by hand also releases; a tag that does not match `build.env` is
rejected. Pull requests and manual runs build and test everything and keep
the packages as workflow artifacts.

## Layout

```
build.env                 versions to build
scripts/fetch-libjxl.sh   clone libjxl + the submodules that get linked in
scripts/build-native.sh   CMake shared build (x64 / arm64; cross-compiles if the runner differs)
scripts/build-wasm.sh     Emscripten static build + link to .js/.wasm (st or mt)
scripts/pack.mjs          assemble and `npm pack` the packages
packages/{native,native-arch,wasm}/   package templates (package.json, README, JS)
tests/                    round-trip smoke tests (C and wasm)
```

## License

This repository (build scripts, package templates, wasm helpers) is MIT
licensed, see `LICENSE`.

## Licenses of the packaged code

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
