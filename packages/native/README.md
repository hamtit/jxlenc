# libjxl-native

Unofficial prebuilt shared libraries of [libjxl](https://github.com/libjxl/libjxl),
the JPEG XL reference implementation, for **Linux x64 and arm64 (glibc)**.

This package is built by [hamtit/jxlenc](https://github.com/hamtit/jxlenc) from
unmodified upstream sources. It is not affiliated with or endorsed by the libjxl
authors or Google.

## Install

Not published to the npm registry; install from the GitHub release:

```sh
npm install https://github.com/hamtit/jxlenc/releases/download/v0.12.0-1/libjxl-native-0.12.0-1.tgz
```

## Contents

```
include/jxl/*.h         public C headers
lib/linux-x64/          libjxl.so.0.12, libjxl_threads.so.0.12, libjxl_cms.so.0.12,
lib/linux-arm64/        libbrotli{enc,dec,common}.so.1 (RUNPATH=$ORIGIN)
licenses/               licenses of all code contained in the libraries
```

Libraries are stored under their SONAME. `libjxl.so` etc. are tiny GNU ld
scripts (`INPUT(libjxl.so.0.12)`) so that `-L<lib dir> -ljxl` works; use the
SONAME files for `dlopen()`.

The libraries need glibc >= 2.38 and libstdc++ (GCC 12 or newer) at run time,
i.e. Ubuntu 24.04 or comparable.

## Usage

```js
const jxl = require('libjxl-native');

jxl.includeDir;          // .../include
jxl.libDir();            // .../lib/linux-x64 (current platform)
jxl.libraryPath('jxl');  // .../lib/linux-x64/libjxl.so.0.12, e.g. for koffi/ffi
```

```sh
DIR=$(node -p "require('libjxl-native').libDir()")
INC=$(node -p "require('libjxl-native').includeDir")
cc app.c -I"$INC" -L"$DIR" -ljxl -ljxl_threads -Wl,-rpath,"$DIR"
```

## Build configuration

libjxl is built with `BUILD_SHARED_LIBS=ON`, skcms as CMS, and without tools,
jpegli, sjpeg, OpenEXR, JNI, tests and plugins. highway is linked statically.

## License

libjxl is licensed under the BSD 3-Clause license, with an additional patent
grant (`licenses/PATENTS.jpeg-xl`). The libraries also contain:

| Component | License | File |
| --- | --- | --- |
| libjxl | BSD-3-Clause | `licenses/LICENSE.jpeg-xl`, `licenses/PATENTS.jpeg-xl` |
| brotli | MIT | `licenses/LICENSE.brotli` |
| highway | Apache-2.0 OR BSD-3-Clause | `licenses/LICENSE.highway`, `licenses/LICENSE-BSD3.highway` |
| skcms | BSD-3-Clause | `licenses/LICENSE.skcms` |
| `index.js`, `index.d.ts` (hamtit/jxlenc) | MIT | `licenses/LICENSE.jxlenc` |

When you redistribute these libraries (e.g. in an application), include the
files from `licenses/`.
