export type LibraryName =
  | 'jxl'
  | 'jxl_cms'
  | 'jxl_threads'
  | 'brotlienc'
  | 'brotlidec'
  | 'brotlicommon';

/** Package version, e.g. "0.12.0-1". */
export declare const version: string;
/** Upstream libjxl version, e.g. "0.12.0". */
export declare const libjxlVersion: string;
/** The single platform this package holds, e.g. ["linux-x64"]. */
export declare const supported: string[];
/** Directory to add to the C include path (contains jxl/*.h). */
export declare const includeDir: string;
/** Directory with the license files of the bundled code. */
export declare const licensesDir: string;
/** Directory with the shared libraries. Throws for any other platform. */
export declare function libDir(platform?: string, arch?: string): string;
/** Absolute path of a library by SONAME, for dlopen()/FFI. */
export declare function libraryPath(
  name?: LibraryName,
  platform?: string,
  arch?: string,
): string;
