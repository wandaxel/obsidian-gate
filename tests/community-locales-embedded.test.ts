/**
 * @file tests/community-locales-embedded.test.ts
 * @summary Community locales (fr, es, ja) must work for a store install.
 *
 * Obsidian installs a community plugin by downloading exactly three release
 * assets - main.js, manifest.json and styles.css - and BRAT does the same.
 * A `locales/` folder next to the plugin therefore never reaches anyone who
 * installs from the store: picking French used to show "Could not load French
 * translation. Using English as fallback." and the UI stayed in English.
 *
 * These tests model that install: the plugin folder has no `locales/` folder,
 * so every disk read fails, and the translations still have to be there.
 */

import { describe, it, expect, vi, beforeEach } from "vitest";
import fs from "node:fs";
import path from "node:path";

const LOCALE_DIR = path.resolve(process.cwd(), "src/platform/translations/locales");
const PLUGIN_DIR = ".obsidian/plugins/learnkit";
const TOKEN = "settings.general.interfaceLanguage.name";

function readLocale(file: string): Record<string, string> {
  return JSON.parse(fs.readFileSync(path.join(LOCALE_DIR, file), "utf8")) as Record<string, string>;
}

const EN = readLocale("en-base.json");

/** A fresh translator module, so bundles registered by one test cannot leak into the next. */
async function freshTranslator() {
  vi.resetModules();
  return import("../src/platform/translations/translator");
}

/** What `app.vault.adapter.read` does for a file that is not in the vault. */
function readerForStoreInstall(): (p: string) => Promise<string> {
  return (p: string) => Promise.reject(new Error(`ENOENT: no such file, open '${p}'`));
}

describe("community locales on a store install (no locales/ folder)", () => {
  beforeEach(() => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.spyOn(console, "debug").mockImplementation(() => {});
  });

  it.each(["fr", "es", "ja"])("selecting %s in settings loads it instead of falling back", async (code) => {
    const expected = readLocale(`community/${code}.json`)[TOKEN];
    expect(expected).toBeTruthy();
    expect(expected).not.toBe(EN[TOKEN]);

    const tr = await freshTranslator();
    tr.setLocaleFileReader(readerForStoreInstall());

    await expect(tr.loadCommunityLocale(PLUGIN_DIR, code)).resolves.toBe(true);
    expect(tr.t(code, TOKEN, "Language")).toBe(expected);
  });

  it("serves French after a restart, before any explicit load", async () => {
    // On restart nothing calls loadCommunityLocale for the saved language:
    // startup only preloads what it finds on disk, which is nothing here.
    const tr = await freshTranslator();
    tr.setLocaleFileReader(readerForStoreInstall());
    await tr.loadLocaleBundlesAsync(PLUGIN_DIR);

    expect(tr.t("fr", TOKEN, "Language")).toBe(readLocale("community/fr.json")[TOKEN]);
  });

  it("still lets a locales/<code>.json on disk override the shipped copy", async () => {
    // Translators test their work by dropping a file into the plugin folder.
    const tr = await freshTranslator();
    tr.setLocaleFileReader((p) =>
      p === `${PLUGIN_DIR}/locales/fr.json`
        ? Promise.resolve(JSON.stringify({ [TOKEN]: "Langue (test traducteur)" }))
        : Promise.reject(new Error("ENOENT")),
    );
    await tr.loadLocaleBundlesAsync(PLUGIN_DIR);

    expect(tr.t("fr", TOKEN, "Language")).toBe("Langue (test traducteur)");
  });
});

describe("community locale inline format", () => {
  it.each(["fr", "es", "ja"])("the build's deflated %s.json decodes to the source file", async (code) => {
    const file = path.join(LOCALE_DIR, "community", `${code}.json`);
    const { deflateJsonForInline } = (await import("../tooling/deflate-inline.cjs")) as {
      deflateJsonForInline: (raw: Buffer) => Buffer;
    };
    const shipped = new Uint8Array(deflateJsonForInline(fs.readFileSync(file)));

    const tr = await freshTranslator();
    expect(tr.decodeEmbeddedLocale(shipped)).toEqual(readLocale(`community/${code}.json`));
    // The point of deflating: keep main.js under Obsidian Sync's 5 MB per-file limit.
    expect(shipped.length).toBeLessThan(fs.statSync(file).size * 0.35);
  });
});
