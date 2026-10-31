# libjxl-wasm

Unofficial build of [libjxl](https://github.com/libjxl/libjxl), the JPEG XL
reference implementation, compiled to WebAssembly with Emscripten. It exposes
the libjxl C API (`JxlEncoder*`, `JxlDecoder*`, ...) as-is.

This package is built by [hamtit/jxlenc](https://github.com/hamtit/jxlenc) from
unmodified upstream sources. It is not affiliated with or endorsed by the libjxl
authors or Google.

## Install

Not published to the npm registry; install from the GitHub release:

```sh
npm install https://github.com/hamtit/jxlenc/releases/download/v0.12.0-1/libjxl-wasm-0.12.0-1.tgz
```

## Variants

| Import | Files | Notes |
| --- | --- | --- |
| `libjxl-wasm` | `dist/libjxl.{js,wasm}` | single-threaded, WASM SIMD128 |
| `libjxl-wasm/mt` | `dist/libjxl-mt.{js,wasm}` | pthreads + SIMD128; needs `SharedArrayBuffer` (cross-origin isolation in browsers) |

Both are ES modules (`MODULARIZE`, `EXPORT_ES6`) for browsers, workers and Node.js.
Memory grows on demand up to 4 GB.

## Usage

```js
import createLibjxl from 'libjxl-wasm';

const jxl = await createLibjxl();
console.log(jxl._JxlEncoderVersion()); // 12000

const enc = jxl._JxlEncoderCreate(0);
const info = jxl._malloc(jxl._jxlwasm_sizeof_basic_info());
jxl._JxlEncoderInitBasicInfo(info);
// ... fill fields via jxl.HEAPU32 etc. (see include/jxl/*.h for layouts)
```

All C functions are exported with a leading underscore; pointers are offsets
into `HEAPU8` and `size_t` is 32-bit. Besides the libjxl API the module exports:

- `_malloc`, `_free`
- `_jxlwasm_sizeof_basic_info`, `_jxlwasm_sizeof_extra_channel_info`,
  `_jxlwasm_sizeof_frame_header`, `_jxlwasm_sizeof_blend_info`,
  `_jxlwasm_sizeof_color_encoding`, `_jxlwasm_sizeof_pixel_format`
- `_jxlwasm_has_threads`
- mt only: `_jxlwasm_thread_parallel_runner`, `_jxlwasm_resizable_parallel_runner`
  return the function pointers to pass to `JxlEncoderSetParallelRunner` /
  `JxlDecoderSetParallelRunner` together with the runner created by
  `_JxlThreadParallelRunnerCreate` / `_JxlResizableParallelRunnerCreate`.
- runtime helpers: `HEAP*`, `getValue`, `setValue`, `UTF8ToString`,
  `stringToUTF8`, `lengthBytesUTF8`, `addFunction`, `removeFunction`

With the mt variant, one worker per logical core is started when the module
is instantiated. Run the encoder in a Worker in browsers, since the calling
thread blocks while waiting for the worker threads.

Bundlers: make sure the `.wasm` file next to the `.js` file is emitted, or pass
`locateFile` / `wasmBinary` to `createLibjxl()`.

## Build configuration

Static libjxl (skcms CMS, no jpegli/sjpeg/tools) built with `-msimd128`.

## License

libjxl is licensed under the BSD 3-Clause license, with an additional patent
grant (`licenses/PATENTS.jpeg-xl`). The modules also contain:

| Component | License | File |
| --- | --- | --- |
| libjxl | BSD-3-Clause | `licenses/LICENSE.jpeg-xl`, `licenses/PATENTS.jpeg-xl` |
| brotli | MIT | `licenses/LICENSE.brotli` |
| highway | Apache-2.0 OR BSD-3-Clause | `licenses/LICENSE.highway`, `licenses/LICENSE-BSD3.highway` |
| skcms | BSD-3-Clause | `licenses/LICENSE.skcms` |
| Emscripten runtime | MIT OR NCSA | `licenses/LICENSE.emscripten` |
| libc++ / libc++abi / compiler-rt | Apache-2.0 WITH LLVM-exception | `licenses/LICENSE.libcxx`, `licenses/LICENSE.libcxxabi`, `licenses/LICENSE.compiler-rt` |
| musl libc | MIT | `licenses/LICENSE.musl` |

When you redistribute these modules (e.g. in a web app), include the files
from `licenses/`.
