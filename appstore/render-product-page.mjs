// Render the declarative product-page.json into exact App Store marketing PNGs.
//
//   npm run product-page --prefix appstore
//   npm run product-page --prefix appstore -- --appearance dark
//
// Raw simulator captures stay in raw/; the rendered panels go to
// product-page/en-US/ and are mirrored to screenshots/en-US/ for ASC upload.

import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const ROOT = dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(readFileSync(join(ROOT, "product-page.json"), "utf8"));
const arg = (name, fallback) => {
  const index = process.argv.indexOf(`--${name}`);
  return index === -1 ? fallback : process.argv[index + 1];
};

const appearance = arg("appearance", config.device.appearance ?? "light");
const width = config.device.width;
const height = config.device.height;
const rawDir = join(ROOT, "raw", config.device.key, appearance);
const productDir = join(ROOT, "product-page", config.locale);
const uploadDir = join(ROOT, "screenshots", config.locale);

if (!existsSync(rawDir)) {
  throw new Error(`No raw captures at ${rawDir}. Run appstore/capture.sh ${appearance} first.`);
}

mkdirSync(productDir, { recursive: true });
mkdirSync(uploadDir, { recursive: true });
for (const directory of [productDir, uploadDir]) {
  for (const file of readdirSync(directory)) {
    if (file.endsWith(".png") || file === "manifest.json") unlinkSync(join(directory, file));
  }
}

const esc = (value = "") => String(value)
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;");

const rich = (value = "") => esc(value).replace(/\*([^*]+)\*/g, "<em>$1</em>");

const mix = (hex, amount, base = "#ffffff") => {
  const parse = (color) => color.slice(1).match(/../g).map((pair) => parseInt(pair, 16));
  const a = parse(hex);
  const b = parse(base);
  const result = a.map((channel, index) => Math.round(channel * amount + b[index] * (1 - amount)));
  return `rgb(${result.join(",")})`;
};

const dataURL = (file) => `data:image/png;base64,${readFileSync(file).toString("base64")}`;

const panelHTML = (panel, image) => {
  const screenWidth = panel.screenWidth ?? 1040;
  // Match Septena's iPhone frame geometry: a uniform 24px bezel around a
  // 158px outer radius, with the screenshot clipped to the concentric inner
  // radius. This reads as an iPhone frame at the 1320px export width.
  const framePadding = 24;
  const frameWidth = screenWidth + framePadding * 2;
  const frameRadius = 158;
  const screenRadius = frameRadius - framePadding;
  const screenTop = panel.screenTop ?? 660;
  const background = panel.background ?? panel.accent;
  const text = panel.text ?? "#ffffff";
  const highlightText = text === "#ffffff"
    ? mix(background, 0.35, "#ffffff")
    : mix(background, 0.60, "#000000");
  const source = image
    ? `<img class="screen" src="${image}" alt="${esc(panel.alt)}">`
    : `<div class="missing">Missing capture<br><small>${esc(panel.source)}</small></div>`;

  return `<!doctype html>
<html><head><meta charset="utf-8"><style>
* { box-sizing: border-box; }
html, body { width:${width}px; height:${height}px; margin:0; overflow:hidden; }
body { font-family:-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif; }
.panel { position:relative; width:${width}px; height:${height}px; overflow:hidden; color:${text};
  background:linear-gradient(145deg, ${mix(background, 0.88, "#ffffff")} 0%, ${background} 54%, ${mix(background, 0.76, "#000000")} 100%); }
.panel::before { content:""; position:absolute; width:1500px; height:1500px; left:-520px; top:-730px;
  border-radius:50%; background:radial-gradient(circle, rgba(255,255,255,.42) 0%, rgba(255,255,255,.14) 34%, transparent 70%); }
.panel::after { content:""; position:absolute; width:670px; height:670px; left:-330px; bottom:360px;
  border-radius:50%; border:3px solid rgba(255,255,255,.24); box-shadow:0 0 90px rgba(255,255,255,.14) inset; }
.copy { position:absolute; z-index:2; top:150px; left:112px; right:112px; }
h1 { max-width:1090px; margin:0; font:700 142px/1.04 -apple-system, BlinkMacSystemFont, sans-serif;
  letter-spacing:-.045em; text-wrap:balance; }
h1 em { color:${highlightText}; font-style:normal; }
.device { position:absolute; z-index:1; left:50%; top:${screenTop}px; width:${frameWidth}px; padding:${framePadding}px;
  transform:translateX(-50%); background:#0c0d0f; border-radius:${frameRadius}px; overflow:hidden;
  box-shadow:0 54px 100px -34px rgba(0,0,0,.52), 0 12px 28px rgba(0,0,0,.15); }
.screen { display:block; width:100%; height:auto; border-radius:${screenRadius}px; }
.missing { aspect-ratio:1320/2868; border-radius:${screenRadius}px; display:flex; align-items:center; justify-content:center;
  flex-direction:column; gap:18px; color:${panel.accent}; background:#f6f6f7; font-size:34px; text-align:center; }
.missing small { font:28px/1.2 ui-monospace, monospace; opacity:.65; }
</style></head><body><main class="panel">
  <section class="copy"><h1>${rich(panel.headline)}</h1></section>
  <div class="device">${source}</div>
</main></body></html>`;
};

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
const manifest = [];

for (const [index, panel] of config.panels.entries()) {
  const sourcePath = join(rawDir, panel.source);
  const image = existsSync(sourcePath) ? dataURL(sourcePath) : null;
  await page.setContent(panelHTML(panel, image), { waitUntil: "load" });
  const outputName = `${String(index + 1).padStart(2, "0")}-${panel.id}-${width}x${height}.png`;
  const outputPath = join(productDir, outputName);
  await page.screenshot({ path: outputPath });
  copyFileSync(outputPath, join(uploadDir, outputName));
  manifest.push({
    order: index + 1,
    id: panel.id,
    source: panel.source,
    file: outputName,
    width,
    height,
    appearance,
    headline: panel.headline,
    alt: panel.alt,
  });
  console.log(`✓ ${outputName}${image ? "" : " (missing source placeholder)"}`);
}

writeFileSync(join(productDir, "manifest.json"), JSON.stringify({ ...config, appearance, exports: manifest }, null, 2) + "\n");
await browser.close();
console.log(`✓ product page exports → ${productDir}`);
console.log(`✓ ASC upload set → ${uploadDir}`);
