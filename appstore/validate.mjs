// Validate store copy and staged screenshot assets without contacting Apple.

import { existsSync, openSync, readSync, closeSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = dirname(fileURLToPath(import.meta.url));
const SOURCE = join(ROOT, "appstore.md");
const SCREENSHOTS = join(ROOT, "screenshots", "en-US");
const text = (await import("node:fs")).readFileSync(SOURCE, "utf8");
const limits = {
  name: 30,
  subtitle: 30,
  promotional_text: 170,
  description: 4000,
  keywords: 100,
  release_notes: 4000,
};

const fields = {};
const headings = [...text.matchAll(/^### ([a-z_]+)\s*$/gm)];
for (const [i, heading] of headings.entries()) {
  const start = heading.index + heading[0].length;
  const end = headings[i + 1]?.index ?? text.length;
  fields[heading[1]] = text.slice(start, end).trim();
}

const issues = [];
for (const [field, limit] of Object.entries(limits)) {
  const value = fields[field] ?? "";
  if (!value) issues.push(`missing ${field}`);
  if (value.length > limit) issues.push(`${field}: ${value.length} > ${limit}`);
}
if (fields.keywords?.includes(", ")) issues.push("keywords: use comma-separated values without spaces");

function pngInfo(file) {
  const buffer = Buffer.alloc(26);
  const fd = openSync(file, "r");
  readSync(fd, buffer, 0, buffer.length, 0);
  closeSync(fd);
  if (buffer.toString("ascii", 1, 4) !== "PNG") return null;
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
    colorType: buffer[25],
  };
}

const shots = existsSync(SCREENSHOTS)
  ? readdirSync(SCREENSHOTS).filter((file) => file.endsWith(".png")).sort()
  : [];
if (shots.length < 1 || shots.length > 10) issues.push(`screenshots: ${shots.length} (expected 1 to 10)`);
for (const shot of shots) {
  const info = pngInfo(join(SCREENSHOTS, shot));
  if (!info) { issues.push(`${shot}: not a PNG`); continue; }
  if (info.width !== 1320 || info.height !== 2868) {
    issues.push(`${shot}: expected 1320×2868, got ${info.width}×${info.height}`);
  }
  if ([4, 6].includes(info.colorType)) issues.push(`${shot}: alpha channel present`);
}

for (const issue of issues) console.log(`✗ ${issue}`);
if (issues.length) process.exit(1);
console.log(`✓ metadata limits passed; ${shots.length} iPhone 6.9-inch screenshot(s) are RGB at 1320×2868`);
