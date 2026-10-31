# libjxl-native-linux-ARCH

Unofficial prebuilt shared libraries of [libjxl](https://github.com/libjxl/libjxl),
the JPEG XL reference implementation, for **Linux ARCH (glibc)** only.

This is the single-platform variant of `libjxl-native` (which bundles x64 and
arm64). It has the same API (`libDir()`, `libraryPath()`, `includeDir`, ...),
but `lib/` holds one platform and the `os`/`cpu` fields let package managers
skip it on any other platform. Use it as an `optionalDependency` next to its
sibling for the other architecture to install only the matching one.

Built by [hamtit/jxlenc](https://github.com/hamtit/jxlenc) from unmodified
upstream sources. Not affiliated with or endorsed by the libjxl authors or
Google.

## Install

Not published to the npm registry; install from the GitHub release:

```sh
npm install https://github.com/hamtit/jxlenc/releases/download/v0.12.0-2/libjxl-native-linux-ARCH-0.12.0-2.tgz
```

## Contents

```
include/jxl/*.h         public C headers
lib/                    libjxl.so.0.12, libjxl_threads.so.0.12, libjxl_cms.so.0.12,
                        libbrotli{enc,dec,common}.so.1 (RUNPATH=$ORIGIN)
licenses/               licenses of all code contained in the libraries
```

See the [libjxl-native README](../native/README.md) for the library layout,
runtime requirements (glibc >= 2.38, libstdc++) and licenses; they are
identical.
