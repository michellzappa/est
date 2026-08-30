// Generate the canonical metadata files consumed by the `asc` CLI.
//
//   node appstore/metadata.mjs
//
// Copy lives in appstore/appstore.md. Generated JSON is intentionally small:
// omitted fields are no-ops when `asc metadata push` applies the directory.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = dirname(fileURLToPath(import.meta.url));
const SOURCE = join(ROOT, "appstore.md");
const OUTPUT = join(ROOT, "metadata");
const LOCALE = "en-US";

const FIELD_MAP = {
  promotional_text: "promotionalText",
  release_notes: "whatsNew",
  support_url: "supportUrl",
  marketing_url: "marketingUrl",
};

const parse = (text) => {
  const platform = text.match(/^## Platform: (.+?) \((.+?)\)\s*$/m);
  if (!platform) throw new Error("Missing iOS platform header");

  const body = text.slice(platform.index + platform[0].length);
  const fields = {};
  const headings = [...body.matchAll(/^### ([a-z_]+)\s*$/gm)];
  for (const [i, heading] of headings.entries()) {
    const start = heading.index + heading[0].length;
    const end = headings[i + 1]?.index ?? body.length;
    fields[heading[1]] = body.slice(start, end).trim();
  }
  return { platform: platform[1], bundleId: platform[2], fields };
};

const parsed = parse(readFileSync(SOURCE, "utf8"));
if (parsed.bundleId !== "com.centaur-labs.est") {
  throw new Error(`Unexpected bundle ID: ${parsed.bundleId}`);
}

const appInfo = {
  name: parsed.fields.name,
  subtitle: parsed.fields.subtitle,
  privacyPolicyUrl: parsed.fields.privacy_url,
};
const version = {};
for (const [source, target] of Object.entries(FIELD_MAP)) {
  version[target] = parsed.fields[source];
}
version.description = parsed.fields.description;
version.keywords = parsed.fields.keywords;

mkdirSync(join(OUTPUT, "app-info"), { recursive: true });
mkdirSync(join(OUTPUT, "version", "1.0.0"), { recursive: true });
writeFileSync(join(OUTPUT, "app-info", `${LOCALE}.json`), `${JSON.stringify(appInfo, null, 2)}\n`);
writeFileSync(join(OUTPUT, "version", "1.0.0", `${LOCALE}.json`), `${JSON.stringify(version, null, 2)}\n`);

console.log(`✓ ${parsed.platform} (${parsed.bundleId}) → appstore/metadata/`);
