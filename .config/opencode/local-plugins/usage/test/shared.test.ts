import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

test("shared parsers and formatting do not import host, credential, or HTTP modules", async () => {
  const seen = new Set<string>();
  async function check(url: URL) {
    if (seen.has(url.href)) return;
    seen.add(url.href);
    assert.doesNotMatch(url.pathname, /\/(credentials|http)\.ts$/);
    const source = await readFile(url, "utf8");
    for (const [, path] of source.matchAll(/(?:\bfrom\s+|\bimport\s*[(']?\s*)["']([^"']+)["']/g)) {
      assert.ok(path!.startsWith("."), `Host-dependent import in ${url.pathname}: ${path}`);
      await check(new URL(path!, url));
    }
  }
  await check(new URL("../shared.ts", import.meta.url));
});
