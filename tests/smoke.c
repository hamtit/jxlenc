// Lossless encode -> decode round trip against the built shared libraries.
// Usage: smoke [num_threads]   (0 = no parallel runner)
#include <jxl/decode.h>
#include <jxl/encode.h>
#include <jxl/thread_parallel_runner.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define W 67
#define H 45

#define CHECK(cond)                                              \
  do {                                                           \
    if (!(cond)) {                                               \
      fprintf(stderr, "%s:%d: check failed: %s\n", __FILE__,     \
              __LINE__, #cond);                                  \
      exit(1);                                                   \
    }                                                            \
  } while (0)

int main(int argc, char** argv) {
  size_t threads = argc > 1 ? (size_t)atoi(argv[1]) : 2;
  printf("libjxl encoder %u, decoder %u\n", JxlEncoderVersion(),
         JxlDecoderVersion());

  uint8_t pixels[W * H * 3];
  for (size_t i = 0; i < sizeof(pixels); i++) pixels[i] = (uint8_t)(i * 7 + i / 13);
  JxlPixelFormat format = {3, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};

  void* runner = threads ? JxlThreadParallelRunnerCreate(NULL, threads) : NULL;

  // Encode.
  JxlEncoder* enc = JxlEncoderCreate(NULL);
  CHECK(enc);
  if (runner) {
    CHECK(JxlEncoderSetParallelRunner(enc, JxlThreadParallelRunner, runner) ==
          JXL_ENC_SUCCESS);
  }
  JxlBasicInfo info;
  JxlEncoderInitBasicInfo(&info);
  info.xsize = W;
  info.ysize = H;
  info.bits_per_sample = 8;
  info.uses_original_profile = JXL_TRUE;
  CHECK(JxlEncoderSetBasicInfo(enc, &info) == JXL_ENC_SUCCESS);
  JxlColorEncoding color;
  JxlColorEncodingSetToSRGB(&color, JXL_FALSE);
  CHECK(JxlEncoderSetColorEncoding(enc, &color) == JXL_ENC_SUCCESS);
  JxlEncoderFrameSettings* fs = JxlEncoderFrameSettingsCreate(enc, NULL);
  CHECK(JxlEncoderSetFrameLossless(fs, JXL_TRUE) == JXL_ENC_SUCCESS);
  CHECK(JxlEncoderAddImageFrame(fs, &format, pixels, sizeof(pixels)) ==
        JXL_ENC_SUCCESS);
  JxlEncoderCloseInput(enc);

  size_t cap = 64, size = 0;
  uint8_t* jxl = malloc(cap);
  for (;;) {
    uint8_t* next = jxl + size;
    size_t avail = cap - size;
    JxlEncoderStatus st = JxlEncoderProcessOutput(enc, &next, &avail);
    size = next - jxl;
    if (st == JXL_ENC_SUCCESS) break;
    CHECK(st == JXL_ENC_NEED_MORE_OUTPUT);
    cap *= 2;
    jxl = realloc(jxl, cap);
  }
  JxlEncoderDestroy(enc);
  printf("encoded %dx%d RGB8 -> %zu bytes\n", W, H, size);
  CHECK(size > 2 && jxl[0] == 0xFF && jxl[1] == 0x0A);

  // Decode.
  JxlDecoder* dec = JxlDecoderCreate(NULL);
  CHECK(dec);
  if (runner) {
    CHECK(JxlDecoderSetParallelRunner(dec, JxlThreadParallelRunner, runner) ==
          JXL_DEC_SUCCESS);
  }
  CHECK(JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO | JXL_DEC_FULL_IMAGE) ==
        JXL_DEC_SUCCESS);
  CHECK(JxlDecoderSetInput(dec, jxl, size) == JXL_DEC_SUCCESS);
  JxlDecoderCloseInput(dec);
  uint8_t out[W * H * 3];
  int got_image = 0;
  for (;;) {
    JxlDecoderStatus st = JxlDecoderProcessInput(dec);
    if (st == JXL_DEC_BASIC_INFO) {
      CHECK(JxlDecoderGetBasicInfo(dec, &info) == JXL_DEC_SUCCESS);
      CHECK(info.xsize == W && info.ysize == H);
    } else if (st == JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
      size_t need;
      CHECK(JxlDecoderImageOutBufferSize(dec, &format, &need) == JXL_DEC_SUCCESS);
      CHECK(need == sizeof(out));
      CHECK(JxlDecoderSetImageOutBuffer(dec, &format, out, sizeof(out)) ==
            JXL_DEC_SUCCESS);
    } else if (st == JXL_DEC_FULL_IMAGE) {
      got_image = 1;
    } else if (st == JXL_DEC_SUCCESS) {
      break;
    } else {
      fprintf(stderr, "unexpected decoder status %d\n", (int)st);
      return 1;
    }
  }
  JxlDecoderDestroy(dec);
  if (runner) JxlThreadParallelRunnerDestroy(runner);
  free(jxl);

  CHECK(got_image);
  CHECK(memcmp(pixels, out, sizeof(out)) == 0);
  printf("round trip OK (%zu threads)\n", threads);
  return 0;
}
