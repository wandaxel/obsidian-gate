/**
 * Inline a file into main.js as a *deflated* zlib stream, base64-encoded.
 *
 * Shared by tooling/esbuild.config.js (which emits the modules) and the tests
 * that pin the format (tests/sql-wasm-inflate.test.ts,
 * tests/community-locales-embedded.test.ts), so build and runtime cannot
 * drift apart. Consumers receive a Uint8Array and must unzlibSync() it.
 */
const zlib = require("zlib");

function deflateForInline(raw) {
  return zlib.deflateSync(raw, { level: zlib.constants.Z_BEST_COMPRESSION });
}

/** Minify, then deflate: whitespace in a locale file is pure overhead. */
function deflateJsonForInline(raw) {
  const minified = JSON.stringify(JSON.parse(raw.toString("utf8")));
  return deflateForInline(Buffer.from(minified, "utf8"));
}

/** An ES module whose default export is the deflated bytes. */
function inlineBytesModule(deflated, comment) {
  const base64 = deflated.toString("base64");
  return (
    `// ${comment}\n` +
    `const base64 = ${JSON.stringify(base64)};\n` +
    `const bytes = typeof Buffer !== "undefined"\n` +
    `  ? new Uint8Array(Buffer.from(base64, "base64"))\n` +
    `  : Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));\n` +
    `export default bytes;\n`
  );
}

module.exports = { deflateForInline, deflateJsonForInline, inlineBytesModule };
