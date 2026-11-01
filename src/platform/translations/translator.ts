/**
 * @file src/platform/translations/translator.ts
 * @summary Module for translator.
 *
 * @exports
 *  - t
 *  - tPlural
 *  - pluralSuffix
 *  - registerLocaleBundle
 *  - isLocaleLoaded
 *  - loadCommunityLocale
 *  - loadLocaleBundlesAsync
 *  - decodeEmbeddedLocale
 */

import { strFromU8, unzlibSync } from "fflate/browser";
import { DEFAULT_INTERFACE_LOCALE, resolveInterfaceLocale, getDownloadableLocales } from "./locale-registry";
import EN_BASE_JSON from "./locales/en-base.json";
import ZH_CN_JSON from "./locales/zh-cn.json";
import TOKEN_ALIASES_JSON from "./locales/token-aliases.json";
import FR_EMBEDDED from "./locales/community/fr.json";
import ES_EMBEDDED from "./locales/community/es.json";
import JA_EMBEDDED from "./locales/community/ja.json";

type TranslationVars = Record<string, string | number>;

const EN_BASE = EN_BASE_JSON as Readonly<Record<string, string>>;
const TOKEN_ALIASES = TOKEN_ALIASES_JSON as Readonly<Record<string, string>>;

/**
 * All loaded message bundles.  Built-in locales are populated at import time;
 * community (downloadable) locales are registered at runtime via
 * {@link registerLocaleBundle} or {@link loadCommunityLocale}.
 */
const MESSAGE_BUNDLES: Record<string, Readonly<Record<string, string>>> = {
  "en-gb": EN_BASE,
  "en-us": EN_BASE,
  "zh-cn": ZH_CN_JSON as Readonly<Record<string, string>>,
};

/**
 * Community locales shipped inside main.js.
 *
 * Obsidian and BRAT install only main.js, manifest.json and styles.css, so a
 * `locales/` folder beside the plugin never reaches a store install. The build
 * inlines these files as deflated zlib streams (deflateCommunityLocalesPlugin
 * in tooling/esbuild.config.js); under vitest no build plugin runs and the
 * import is the parsed JSON, so {@link decodeEmbeddedLocale} accepts both.
 */
const EMBEDDED_COMMUNITY_LOCALES: Readonly<Record<string, unknown>> = {
  fr: FR_EMBEDDED,
  es: ES_EMBEDDED,
  ja: JA_EMBEDDED,
};

/** Locales whose embedded copy was already tried, so a bad one is not re-inflated on every t(). */
const EMBEDDED_TRIED = new Set<string>();

/** Turn an embedded locale (deflated bytes in main.js, parsed JSON under vitest) into a bundle. */
export function decodeEmbeddedLocale(value: unknown): Record<string, string> | null {
  if (value instanceof Uint8Array) {
    return JSON.parse(strFromU8(unzlibSync(value))) as Record<string, string>;
  }
  if (value && typeof value === "object") return value as Record<string, string>;
  return null;
}

/** The bundle for a locale, inflating its embedded copy the first time it is needed. */
function getBundle(locale: string): Readonly<Record<string, string>> | undefined {
  const loaded = MESSAGE_BUNDLES[locale];
  if (loaded || EMBEDDED_TRIED.has(locale)) return loaded;
  EMBEDDED_TRIED.add(locale);
  try {
    const bundle = decodeEmbeddedLocale(EMBEDDED_COMMUNITY_LOCALES[locale]);
    if (bundle) MESSAGE_BUNDLES[locale] = bundle;
  } catch (err) {
    console.warn(`[translator] embedded "${locale}" translation could not be decoded:`, err);
  }
  return MESSAGE_BUNDLES[locale];
}

function interpolate(template: string, vars?: TranslationVars): string {
  if (!vars) return template;
  return template.replace(/\{([a-zA-Z0-9_.-]+)\}/g, (_m, key: string) => {
    const v = vars[key];
    return v == null ? `{${key}}` : String(v);
  });
}

export function t(
  locale: unknown,
  token: string,
  fallback: string,
  vars?: TranslationVars,
): string {
  const resolvedLocale = resolveInterfaceLocale(locale);
  const resolvedToken = TOKEN_ALIASES[token] ?? token;
  const primary = getBundle(resolvedLocale)?.[resolvedToken];
  const english = MESSAGE_BUNDLES[DEFAULT_INTERFACE_LOCALE]?.[resolvedToken];
  const chosen = primary ?? english ?? fallback;
  return interpolate(chosen, vars);
}

/**
 * Returns "s" when count !== 1, "" otherwise.
 * Convenience for English-style plurals — translators for other languages
 * can override the full string via `tPlural` instead.
 */
export function pluralSuffix(count: number): string {
  return count === 1 ? "" : "s";
}

/**
 * Translate with automatic plural suffix injection.
 * Adds `{count}` and `{suffix}` ("" or "s") to the vars automatically.
 * Translators for non-English locales can override the template entirely
 * using their own grammar rules since the full phrase is a single token.
 */
export function tPlural(
  locale: unknown,
  token: string,
  fallback: string,
  count: number,
  vars?: TranslationVars,
): string {
  return t(locale, token, fallback, {
    ...vars,
    count,
    suffix: pluralSuffix(count),
  });
}

// ── Dynamic locale loading ──────────────────────────────────────────

/**
 * Register a locale bundle at runtime.  Safe to call multiple times; later
 * registrations overwrite earlier ones.
 */
export function registerLocaleBundle(code: string, bundle: Record<string, string>): void {
  MESSAGE_BUNDLES[code] = bundle;
}

/**
 * Returns true when the given locale code has a registered bundle.
 */
export function isLocaleLoaded(code: string): boolean {
  const resolved = resolveInterfaceLocale(code);
  return resolved in MESSAGE_BUNDLES;
}

/**
 * Read adapter for loading locale JSON files from disk.  Injected by the
 * plugin host so the pure translator module stays environment-agnostic.
 */
let _readFile: ((path: string) => Promise<string>) | null = null;

/**
 * Configure the file reader used by {@link loadCommunityLocale}.
 * Call once during plugin startup, e.g.:
 *   setLocaleFileReader((path) => app.vault.adapter.read(path))
 */
export function setLocaleFileReader(readFile: (path: string) => Promise<string>): void {
  _readFile = readFile;
}

/**
 * Register `<pluginDir>/locales/<code>.json` if it exists. A missing file is
 * the normal case (store installs have no locales/ folder) and stays silent.
 */
async function loadLocaleFromDisk(pluginDir: string, code: string): Promise<boolean> {
  if (!_readFile) return false;
  const jsonPath = `${pluginDir}/locales/${code}.json`;
  let raw: string;
  try {
    raw = await _readFile(jsonPath);
  } catch {
    return false;
  }
  try {
    registerLocaleBundle(code, JSON.parse(raw) as Record<string, string>);
    return true;
  } catch (err) {
    console.warn(`[translator] ignoring ${jsonPath}: not valid JSON`, err);
    return false;
  }
}

/**
 * Load a community locale. A `locales/<code>.json` file in the plugin folder
 * wins, so translators can test their work in place; otherwise the copy
 * shipped inside main.js is used.
 *
 * @param pluginDir - The plugin's directory path (e.g. `"path/.obsidian/plugins/learnkit"`).
 * @param code       - Locale code to load (e.g. `"fr"`, `"ja"`, `"es"`).
 * @returns true when the locale was loaded successfully, false otherwise.
 */
export async function loadCommunityLocale(pluginDir: string, code: string): Promise<boolean> {
  const resolved = resolveInterfaceLocale(code);
  if (resolved === "en-gb" || resolved === "en-us" || resolved === "zh-cn") {
    return true; // already bundled
  }

  const downloadable = getDownloadableLocales();
  if (!downloadable.includes(resolved)) {
    console.warn(`[translator] loadCommunityLocale: "${resolved}" is not a downloadable locale`);
    return false;
  }

  if (await loadLocaleFromDisk(pluginDir, resolved)) return true;
  if (getBundle(resolved)) return true;

  console.warn(`[translator] loadCommunityLocale: no "${resolved}" translation on disk or in main.js`);
  return false;
}

/**
 * Preloads any community locale files found on disk, so they override the
 * copies shipped in main.js. Those embedded copies need no preload: t()
 * inflates the one in use on first use.
 *
 * @param pluginDir - The plugin's directory path.
 */
export async function loadLocaleBundlesAsync(pluginDir: string): Promise<void> {
  const downloadable = getDownloadableLocales();
  const results = await Promise.allSettled(
    downloadable.map((code) => loadLocaleFromDisk(pluginDir, code)),
  );

  const loaded = results.filter((r) => r.status === "fulfilled" && r.value).length;
  if (loaded > 0) {
    console.debug(`[translator] Preloaded ${loaded} community locale(s)`);
  }

  const failures = results.filter((r) => r.status === "rejected");
  for (const f of failures) {
    console.warn("[translator] Failed to preload a community locale:", f.reason);
  }
}
