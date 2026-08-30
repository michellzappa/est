// The device classes EST ships to the App Store. One entry per screenshot set.
//
// Layout model, adapted from Septena: every device renders in a shared design
// space 1320 units wide, then Playwright scales that space to the real pixel
// size. The type scale is therefore identical on iPhone and iPad, and only the
// proportions change. `designHeight` must satisfy
// `designHeight * (width / designWidth) === height`, which the assertion below
// enforces, because Playwright rounds a mismatch into an off-by-one export that
// App Store Connect rejects.
//
// Sizes verified against the ASC screenshot specs (2026):
//   iPhone 6.9" 1320×2868 — ASC scales the smaller iPhone shelves from it
//   iPad 13"    2064×2752 — required for any app that supports iPad
// Rules: PNG, RGB with no alpha, exact pixels, 1 to 10 shots per class.

export const DEVICES = {
  iphone69: {
    label: 'iPhone 6.9"',
    ascDeviceType: "IPHONE_69",
    simulator: "iPhone 16 Pro Max",
    width: 1320,
    height: 2868,
    designWidth: 1320,
    designHeight: 2868,
    // The frame bleeds past the bottom of the canvas on purpose.
    frame: { padding: 24, radius: 158, screenTop: 660, screenWidth: 1040 },
  },
  ipad13: {
    label: 'iPad 13"',
    ascDeviceType: "IPAD_PRO_3GEN_129",
    simulator: "iPad Pro 13-inch (M4)",
    width: 2064,
    height: 2752,
    designWidth: 1320,
    designHeight: 1760,
    // An iPad is wider and shorter, so the frame sits higher, stays narrower
    // relative to the canvas, and uses a much smaller corner radius.
    frame: { padding: 22, radius: 92, screenTop: 560, screenWidth: 940 },
  },
};

export const DEVICE_KEYS = Object.keys(DEVICES);

for (const [key, d] of Object.entries(DEVICES)) {
  const scaled = d.designHeight * (d.width / d.designWidth);
  if (Math.round(scaled) !== d.height) {
    throw new Error(
      `${key}: designHeight ${d.designHeight} scales to ${scaled}, expected ${d.height}`,
    );
  }
}

export function device(key) {
  const found = DEVICES[key];
  if (!found) {
    throw new Error(`Unknown device "${key}". Known: ${DEVICE_KEYS.join(", ")}`);
  }
  return { key, ...found, zoom: found.width / found.designWidth };
}
