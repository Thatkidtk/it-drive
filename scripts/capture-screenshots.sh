#!/bin/bash
# Interactive screenshot helper for macOS.
# Captures a few key moments to PNGs under docs/screens/.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
OUT_DIR="$ROOT_DIR/docs/screens"
mkdir -p "$OUT_DIR"

echo "This will prompt you to capture screenshots (use Cmd+Ctrl+Shift+4 for area, or window capture)."
echo "Images are saved to: $OUT_DIR"

read -r -p "Ready to capture the launcher (Finder showing it-tool folder)? Press Enter..." _
screencapture -i "$OUT_DIR/01-it-tool-folder.png"

read -r -p "Capture Terminal after running Start-macOS-Python.command (report generating). Press Enter..." _
screencapture -i "$OUT_DIR/02-terminal-running.png"

read -r -p "Capture the HTML report opened in your browser. Press Enter..." _
screencapture -i "$OUT_DIR/03-html-report.png"

read -r -p "Capture the safe fixes prompt in Terminal. Press Enter..." _
screencapture -i "$OUT_DIR/04-safe-fixes.png"

echo "Done. Screenshots saved in $OUT_DIR"

