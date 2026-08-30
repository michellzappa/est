#!/usr/bin/env bash
# Stage the selected raw captures in App Store Connect order.
#
#   appstore/stage.sh [light|dark]
set -euo pipefail

APPEARANCE="${1:-light}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$ROOT/appstore/raw/iphone69/$APPEARANCE"
OUT="$ROOT/appstore/screenshots/en-US"

[ -d "$RAW" ] || { echo "No raw capture directory: $RAW"; exit 1; }
rm -rf "$OUT"
mkdir -p "$OUT"

shots=(title solo-81 quick-27 duel rules mathematics)
for index in "${!shots[@]}"; do
  name="${shots[$index]}"
  source="$RAW/$name.png"
  [ -f "$source" ] || { echo "Missing raw screenshot: $source"; exit 1; }
  printf -v number '%02d' "$((index + 1))"
  cp "$source" "$OUT/${number}-${name}-1320x2868.png"
done

echo "✓ staged ${#shots[@]} iPhone screenshots → appstore/screenshots/en-US"
