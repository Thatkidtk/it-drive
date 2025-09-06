#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
VERSION="${1:-v1.0.0}"
OUT="it-drive-${VERSION}.zip"

cd "$ROOT_DIR/.."
echo "Creating ${OUT} from it-drive/it-tool ..."
zip -qr "$OUT" "it-drive/it-tool"
echo "Wrote: $(pwd)/${OUT}"

