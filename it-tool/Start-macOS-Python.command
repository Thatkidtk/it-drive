#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/mac"

PYTHON_BIN="${PYTHON_BIN:-python3}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "python3 not found. Please install Command Line Tools (xcode-select --install) or Python."
  exit 1
fi

"$PYTHON_BIN" ./pytool.py audit --html --open || true

read -r -p "Run safe fixes now? [y/N] " ans
case "${ans:-N}" in
  [Yy]*) "$PYTHON_BIN" ./pytool.py fix ;;
  *) echo "Skipped fixes.";;
esac

echo
echo "Done. Close this window when finished."
