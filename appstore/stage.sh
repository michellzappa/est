#!/usr/bin/env bash
# Stage the selected raw captures in App Store Connect order, unframed.
#
#   appstore/stage.sh <device> [light|dark]
#     device: iphone69 | ipad13
#
# This writes the plain simulator captures. `npm run product-page` overwrites
# the same directory with the framed marketing panels, so run stage.sh alone
# only when the listing should show bare screenshots.
set -euo pipefail

DEVICE="${1:?usage: appstore/stage.sh <iphone69|ipad13> [light|dark]}"
APPEARANCE="${2:-light}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$ROOT/appstore/raw/$DEVICE/$APPEARANCE"
OUT="$ROOT/appstore/screenshots/$DEVICE/en-US"

# devices.mjs is the single source of truth for the exported pixel size.
SIZE="$(cd "$ROOT" && node --input-type=module -e \
  'import { device } from "./appstore/devices.mjs"; const d = device(process.argv[1]); console.log(`${d.width}x${d.height}`);' \
  "$DEVICE")" || { echo "Unknown device: $DEVICE"; exit 1; }

[ -d "$RAW" ] || { echo "No raw capture directory: $RAW"; exit 1; }
rm -rf "$OUT"
mkdir -p "$OUT"

shots=(title solo-81 quick-27 duel rules mathematics)
for index in "${!shots[@]}"; do
  name="${shots[$index]}"
  source="$RAW/$name.png"
  [ -f "$source" ] || { echo "Missing raw screenshot: $source"; exit 1; }
  printf -v number '%02d' "$((index + 1))"
  cp "$source" "$OUT/${number}-${name}-${SIZE}.png"
done

echo "✓ staged ${#shots[@]} $DEVICE screenshots → appstore/screenshots/$DEVICE/en-US"
