#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
LOG_DIR="$BASE_DIR/logs"
OLLAMA_DIR="$BASE_DIR/ollama"
MODEL_STORE="$OLLAMA_DIR/models"

mkdir -p "$LOG_DIR" "$MODEL_STORE"

note() { echo "[it-tool] $*"; }
warn() { echo "[it-tool][warn] $*"; }

detect_ollama() {
  local b1="$OLLAMA_DIR/Ollama.app/Contents/MacOS/ollama"
  local b2="$OLLAMA_DIR/Ollama.app/Contents/MacOS/Ollama"
  if [[ -x "$b1" ]]; then echo "$b1"; return 0; fi
  if [[ -x "$b2" ]]; then echo "$b2"; return 0; fi
  if command -v ollama >/dev/null 2>&1; then command -v ollama; return 0; fi
  echo ""; return 1
}

pick_file_interactive() {
  osascript -e 'try	on run {}
    set f to choose file with prompt "Select a .ollama model bundle to import" of type {"ollama"}
    POSIX path of f
  on error
    return ""
  end try'
}

main() {
  local ollama_bin
  ollama_bin=$(detect_ollama || true)
  if [[ -z "$ollama_bin" ]]; then
    warn "Ollama not found. Place Ollama.app under $OLLAMA_DIR or install system-wide."
    exit 1
  fi

  local bundle_path="${1:-}"
  if [[ -z "$bundle_path" ]]; then
    bundle_path="$(pick_file_interactive)"
  fi

  if [[ -z "$bundle_path" ]]; then
    warn "No bundle selected. You can also put .ollama files into $BASE_DIR/ollama/bundles and run the main agent to auto-import."
    exit 1
  fi

  if [[ ! -f "$bundle_path" ]]; then
    warn "File not found: $bundle_path"
    exit 1
  fi

  note "Starting Ollama server (models at $MODEL_STORE)"
  OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" serve >"$LOG_DIR/ollama-serve.log" 2>&1 &

  # Wait until ready
  for i in {1..20}; do
    if OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" list >/dev/null 2>&1; then break; fi
    sleep 0.5
  done

  note "Importing bundle: $bundle_path"
  if OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" import "$bundle_path" >>"$LOG_DIR/ollama-import.log" 2>&1; then
    note "Import successful. Available models:"
    OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" list || true
  else
    warn "Import failed. See $LOG_DIR/ollama-import.log for details."
    exit 2
  fi
}

main "$@"
