#!/bin/bash
# Build an animated GIF from PNGs in docs/screens/ using ImageMagick (convert).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
SRC_DIR="$ROOT_DIR/docs/screens"
OUT_GIF="$ROOT_DIR/docs/getting-started.gif"

if ! command -v convert >/dev/null 2>&1; then
  echo "ImageMagick 'convert' not found. Install via: brew install imagemagick" >&2
  exit 1
fi

if ! ls "$SRC_DIR"/*.png >/dev/null 2>&1; then
  echo "No PNGs found in $SRC_DIR. Run capture-screenshots.sh first." >&2
  exit 1
fi

echo "Creating $OUT_GIF from PNG frames in $SRC_DIR ..."
convert -delay 120 -loop 0 \
  "$SRC_DIR"/01-it-tool-folder.png \
  "$SRC_DIR"/02-terminal-running.png \
  "$SRC_DIR"/03-html-report.png \
  "$SRC_DIR"/04-safe-fixes.png \
  -resize 1280x -layers Optimize "$OUT_GIF"

echo "Wrote: $OUT_GIF"

