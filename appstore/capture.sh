#!/usr/bin/env bash
# Capture raw App Store screenshots from the EST UI-test target.
#
#   appstore/capture.sh <device> [light|dark]
#     device: iphone69 | ipad13
#
# The raw captures go to appstore/raw/<device>/<appearance>/. They are kept
# separate from the final staged screenshots so the marketing order can change
# without re-running the simulator.
#
# The UI test makes no device or orientation assumptions, so the same test
# target produces both sets. Only the simulator changes.
set -euo pipefail

DEVICE="${1:?usage: appstore/capture.sh <iphone69|ipad13> [light|dark]}"
APPEARANCE="${2:-light}"
case "$APPEARANCE" in
  light|dark) ;;
  *) echo "usage: appstore/capture.sh <device> [light|dark]"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# devices.mjs is the single source of truth for the simulator per device class.
SIM_DEFAULT="$(node --input-type=module -e \
  'import { device } from "./appstore/devices.mjs"; console.log(device(process.argv[1]).simulator);' \
  "$DEVICE")" || { echo "Unknown device: $DEVICE"; exit 1; }
SIM_NAME="${EST_SIMULATOR_NAME:-$SIM_DEFAULT}"
SIM_ID="$(xcrun simctl list devices available | grep "$SIM_NAME (" | head -1 | grep -oE '\([0-9A-F-]{36}\)' | tr -d '()')"
[ -n "$SIM_ID" ] || { echo "No '$SIM_NAME' simulator found"; exit 1; }

xcrun simctl boot "$SIM_ID" 2>/dev/null || true
xcrun simctl ui "$SIM_ID" appearance "$APPEARANCE" 2>/dev/null || true
xcrun simctl status_bar "$SIM_ID" override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode notSupported \
  --batteryState charged --batteryLevel 100 2>/dev/null || true

RESULT="/tmp/est-appstore-${DEVICE}-${APPEARANCE}.xcresult"
OUT="$ROOT/appstore/raw/$DEVICE/$APPEARANCE"
rm -rf "$RESULT" "$OUT"
mkdir -p "$OUT"

xcodebuild test \
  -project EST.xcodeproj \
  -scheme EST \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -resultBundlePath "$RESULT" \
  -only-testing:ESTUITests/ScreenshotTests \
  -configuration Debug

xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT" >/dev/null

python3 - "$OUT" <<'PY'
import json
import os
import sys

directory = sys.argv[1]
manifest_path = os.path.join(directory, "manifest.json")
with open(manifest_path, encoding="utf-8") as handle:
    manifest = json.load(handle)

for attachment in manifest[0]["attachments"]:
    source = os.path.join(directory, attachment["exportedFileName"])
    if not os.path.exists(source):
        continue
    name = attachment["suggestedHumanReadableName"].split("_0_")[0]
    if name.startswith("00-"):
        os.remove(source)
        continue
    if not name.endswith((".png", ".txt")):
        name += ".png"
    os.rename(source, os.path.join(directory, name))

os.remove(manifest_path)
print("✓ captured:", ", ".join(sorted(name for name in os.listdir(directory) if name.endswith(".png"))))
PY

echo "✓ raw screenshots → appstore/raw/$DEVICE/$APPEARANCE"
