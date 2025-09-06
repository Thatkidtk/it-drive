#!/bin/bash
set -euo pipefail

# Ensure we resolve the script directory even when double-clicked
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/mac"

"./agent.sh"

echo
echo "Done. Close this window when finished."

