#!/bin/bash
# Release helper: bump version, build zip, push and tag
# Usage: scripts/release.sh vX.Y.Z "Summary for changelog"
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
NEW_VER="${1:-}"
SUMMARY="${2:-}"

if [[ -z "$NEW_VER" ]]; then
  echo "Usage: scripts/release.sh vX.Y.Z [summary]" >&2
  exit 1
fi

"$ROOT_DIR/scripts/bump-version.sh" "$NEW_VER" "${SUMMARY:-}"

cd "$ROOT_DIR/.."
bash it-drive/scripts/build-zip.sh "$NEW_VER"

cd "$ROOT_DIR"
git push -u origin main
git push origin "$NEW_VER"

echo "Release $NEW_VER pushed. GitHub Actions will publish assets shortly."

