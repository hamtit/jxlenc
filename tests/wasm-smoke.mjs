// Lossless encode -> decode round trip through the wasm module, mirroring
// tests/smoke.c. Usage: node wasm-smoke.mjs <module specifier or path>
import assert from 'node:assert/strict';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const spec = process.argv[2] ?? 'libjxl-wasm';
const url = spec.startsWith('.') || path.isAbsolute(spec) ? pathToFileURL(path.resolve(spec)).href : spec;
const { default: createLibjxl } = await import(url);
const m = await createLibjxl();

const W = 67, H = 45;
const JXL_TYPE_UINT8 = 2, JXL_NATIVE_ENDIAN = 0;
const ENC_SUCCESS = 0, ENC_NEED_MORE_OUTPUT = 2;
const DEC_SUCCESS = 0, DEC_NEED_IMAGE_OUT_BUFFER = 5, DEC_BASIC_INFO = 0x40, DEC_FULL_IMAGE = 0x1000;
// JxlBasicInfo field offsets (no pointer/size_t members, same as native).
const BI_XSIZE = 4, BI_YSIZE = 8, BI_BITS = 12, BI_ORIGINAL_PROFILE = 36;

const u32 = (ptr) => m.HEAPU32[ptr >> 2];
const setU32 = (ptr, v) => { m.HEAPU32[ptr >> 2] = v; };

console.log(`libjxl encoder ${m._JxlEncoderVersion()}, decoder ${m._JxlDecoderVersion()}`);
const threads = m._jxlwasm_has_threads() ? 2 : 0;
assert.equal(m._jxlwasm_sizeof_pixel_format(), 16);

const size = W * H * 3;
const pixels = new Uint8Array(size);
for (let i = 0; i < size; i++) pixels[i] = (i * 7 + Math.floor(i / 13)) & 0xff;

const format = m._malloc(m._jxlwasm_sizeof_pixel_format());
setU32(format, 3);
setU32(format + 4, JXL_TYPE_UINT8);
setU32(format + 8, JXL_NATIVE_ENDIAN);
setU32(format + 12, 0);

let runner = 0, runnerFn = 0;
if (threads) {
  runner = m._JxlThreadParallelRunnerCreate(0, threads);
  assert.ok(runner);
  runnerFn = m._jxlwasm_thread_parallel_runner();
}

// Encode.
const enc = m._JxlEncoderCreate(0);
assert.ok(enc);
if (runner) assert.equal(m._JxlEncoderSetParallelRunner(enc, runnerFn, runner), ENC_SUCCESS);
const info = m._malloc(m._jxlwasm_sizeof_basic_info());
m._JxlEncoderInitBasicInfo(info);
setU32(info + BI_XSIZE, W);
setU32(info + BI_YSIZE, H);
setU32(info + BI_BITS, 8);
setU32(info + BI_ORIGINAL_PROFILE, 1);
assert.equal(m._JxlEncoderSetBasicInfo(enc, info), ENC_SUCCESS);
const color = m._malloc(m._jxlwasm_sizeof_color_encoding());
m._JxlColorEncodingSetToSRGB(color, 0);
assert.equal(m._JxlEncoderSetColorEncoding(enc, color), ENC_SUCCESS);
const fs = m._JxlEncoderFrameSettingsCreate(enc, 0);
assert.equal(m._JxlEncoderSetFrameLossless(fs, 1), ENC_SUCCESS);
const pix = m._malloc(size);
m.HEAPU8.set(pixels, pix);
assert.equal(m._JxlEncoderAddImageFrame(fs, format, pix, size), ENC_SUCCESS);
m._JxlEncoderCloseInput(enc);

const cap = 1 << 20;
const outBuf = m._malloc(cap);
const nextOut = m._malloc(4), availOut = m._malloc(4);
setU32(nextOut, outBuf);
setU32(availOut, cap);
assert.equal(m._JxlEncoderProcessOutput(enc, nextOut, availOut), ENC_SUCCESS, 'output fits in 1 MiB');
const jxlSize = u32(nextOut) - outBuf;
m._JxlEncoderDestroy(enc);
console.log(`encoded ${W}x${H} RGB8 -> ${jxlSize} bytes`);
assert.ok(jxlSize > 2 && m.HEAPU8[outBuf] === 0xff && m.HEAPU8[outBuf + 1] === 0x0a);

// Decode.
const dec = m._JxlDecoderCreate(0);
assert.ok(dec);
if (runner) assert.equal(m._JxlDecoderSetParallelRunner(dec, runnerFn, runner), DEC_SUCCESS);
assert.equal(m._JxlDecoderSubscribeEvents(dec, DEC_BASIC_INFO | DEC_FULL_IMAGE), DEC_SUCCESS);
assert.equal(m._JxlDecoderSetInput(dec, outBuf, jxlSize), DEC_SUCCESS);
m._JxlDecoderCloseInput(dec);
const out = m._malloc(size);
const need = m._malloc(4);
let gotImage = false;
for (;;) {
  const st = m._JxlDecoderProcessInput(dec);
  if (st === DEC_BASIC_INFO) {
    assert.equal(m._JxlDecoderGetBasicInfo(dec, info), DEC_SUCCESS);
    assert.equal(u32(info + BI_XSIZE), W);
    assert.equal(u32(info + BI_YSIZE), H);
  } else if (st === DEC_NEED_IMAGE_OUT_BUFFER) {
    assert.equal(m._JxlDecoderImageOutBufferSize(dec, format, need), DEC_SUCCESS);
    assert.equal(u32(need), size);
    assert.equal(m._JxlDecoderSetImageOutBuffer(dec, format, out, size), DEC_SUCCESS);
  } else if (st === DEC_FULL_IMAGE) {
    gotImage = true;
  } else if (st === DEC_SUCCESS) {
    break;
  } else {
    assert.fail(`unexpected decoder status ${st}`);
  }
}
m._JxlDecoderDestroy(dec);
if (runner) m._JxlThreadParallelRunnerDestroy(runner);

assert.ok(gotImage);
assert.deepEqual(m.HEAPU8.slice(out, out + size), pixels);
for (const p of [format, info, color, pix, outBuf, nextOut, availOut, out, need]) m._free(p);
console.log(`round trip OK (${threads} threads)`);
// The mt variant keeps its worker pool alive; exit explicitly.
process.exit(0);
