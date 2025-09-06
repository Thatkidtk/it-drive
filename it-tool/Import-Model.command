#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/mac"

"./import-model.sh" "$@"

echo
echo "Done. Close this window when finished."

