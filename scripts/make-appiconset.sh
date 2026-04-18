#!/bin/bash
# Convert assets/icon.png (1024x1024) -> NotchFlow/Resources/Assets.xcassets/AppIcon.appiconset
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="${1:-assets/icon.png}"
OUT="${2:-NotchFlow/Resources/Assets.xcassets/AppIcon.appiconset}"

if [ ! -f "$SRC" ]; then
  echo "missing $SRC — run 'swift scripts/make-icon.swift' first" >&2
  exit 1
fi

mkdir -p "$OUT"

sips -z 16 16 "$SRC" --out "$OUT/icon_16x16.png" >/dev/null
sips -z 32 32 "$SRC" --out "$OUT/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SRC" --out "$OUT/icon_32x32.png" >/dev/null
sips -z 64 64 "$SRC" --out "$OUT/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SRC" --out "$OUT/icon_128x128.png" >/dev/null
sips -z 256 256 "$SRC" --out "$OUT/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SRC" --out "$OUT/icon_256x256.png" >/dev/null
sips -z 512 512 "$SRC" --out "$OUT/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SRC" --out "$OUT/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SRC" --out "$OUT/icon_512x512@2x.png" >/dev/null

echo "==> updated $OUT"
