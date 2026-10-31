'use strict';

const fs = require('node:fs');
const path = require('node:path');

const pkg = require('./package.json');

const SUPPORTED = ['linux-x64', 'linux-arm64'];

const includeDir = path.join(__dirname, 'include');
const licensesDir = path.join(__dirname, 'licenses');

function target(platform, arch) {
  const t = `${platform}-${arch}`;
  if (!SUPPORTED.includes(t)) {
    throw new Error(
      `libjxl-native: no prebuilt libraries for ${t} (available: ${SUPPORTED.join(', ')})`,
    );
  }
  return t;
}

/** Directory containing the shared libraries for the given platform. */
function libDir(platform = process.platform, arch = process.arch) {
  return path.join(__dirname, 'lib', target(platform, arch));
}

/**
 * Absolute path of a library, named by its SONAME (e.g. libjxl.so.0.12),
 * suitable for dlopen() / FFI loaders.
 * @param {'jxl'|'jxl_cms'|'jxl_threads'|'brotlienc'|'brotlidec'|'brotlicommon'} name
 */
function libraryPath(name = 'jxl', platform = process.platform, arch = process.arch) {
  const dir = libDir(platform, arch);
  const prefix = `lib${name}.so.`;
  const file = fs.readdirSync(dir).find((f) => f.startsWith(prefix));
  if (!file) throw new Error(`libjxl-native: library ${name} not found in ${dir}`);
  return path.join(dir, file);
}

module.exports = {
  version: pkg.version,
  libjxlVersion: pkg.libjxl.version,
  supported: SUPPORTED.slice(),
  includeDir,
  licensesDir,
  libDir,
  libraryPath,
};
