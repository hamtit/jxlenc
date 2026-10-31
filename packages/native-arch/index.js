'use strict';

const fs = require('node:fs');
const path = require('node:path');

const pkg = require('./package.json');

// This package holds the libraries of exactly one platform.
const TARGET = `${pkg.os[0]}-${pkg.cpu[0]}`;

const includeDir = path.join(__dirname, 'include');
const licensesDir = path.join(__dirname, 'licenses');

function check(platform, arch) {
  if (`${platform}-${arch}` !== TARGET) {
    throw new Error(`${pkg.name}: only contains libraries for ${TARGET}, not ${platform}-${arch}`);
  }
}

/** Directory containing the shared libraries. Throws for any other platform. */
function libDir(platform = process.platform, arch = process.arch) {
  check(platform, arch);
  return path.join(__dirname, 'lib');
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
  if (!file) throw new Error(`${pkg.name}: library ${name} not found in ${dir}`);
  return path.join(dir, file);
}

module.exports = {
  version: pkg.version,
  libjxlVersion: pkg.libjxl.version,
  supported: [TARGET],
  includeDir,
  licensesDir,
  libDir,
  libraryPath,
};
