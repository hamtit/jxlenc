// Small helpers linked into the wasm module next to the libjxl C API.
//
// In wasm a C function pointer is an index into the function table, which
// the exported JS wrappers (Module._JxlThreadParallelRunner etc.) do not
// give you. These return the pointers that JxlEncoderSetParallelRunner /
// JxlDecoderSetParallelRunner expect. Struct sizes are exported so JS code
// can allocate them without hard-coding layout assumptions.
#include <emscripten/emscripten.h>
#include <jxl/codestream_header.h>
#include <jxl/color_encoding.h>
#include <jxl/types.h>
#include <stddef.h>

#ifdef JXLWASM_THREADS
#include <jxl/resizable_parallel_runner.h>
#include <jxl/thread_parallel_runner.h>

EMSCRIPTEN_KEEPALIVE JxlParallelRunner jxlwasm_thread_parallel_runner(void) {
  return JxlThreadParallelRunner;
}

EMSCRIPTEN_KEEPALIVE JxlParallelRunner
jxlwasm_resizable_parallel_runner(void) {
  return JxlResizableParallelRunner;
}
#endif

EMSCRIPTEN_KEEPALIVE int jxlwasm_has_threads(void) {
#ifdef JXLWASM_THREADS
  return 1;
#else
  return 0;
#endif
}

EMSCRIPTEN_KEEPALIVE size_t jxlwasm_sizeof_basic_info(void) {
  return sizeof(JxlBasicInfo);
}

EMSCRIPTEN_KEEPALIVE size_t jxlwasm_sizeof_extra_channel_info(void) {
  return sizeof(JxlExtraChannelInfo);
}

EMSCRIPTEN_KEEPALIVE size_t jxlwasm_sizeof_frame_header(void) {
  return sizeof(JxlFrameHeader);
}

EMSCRIPTEN_KEEPALIVE size_t jxlwasm_sizeof_blend_info(void) {
  return sizeof(JxlBlendInfo);
}

EMSCRIPTEN_KEEPALIVE size_t jxlwasm_sizeof_color_encoding(void) {
  return sizeof(JxlColorEncoding);
}

EMSCRIPTEN_KEEPALIVE size_t jxlwasm_sizeof_pixel_format(void) {
  return sizeof(JxlPixelFormat);
}
