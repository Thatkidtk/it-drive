#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
LOG_DIR="$BASE_DIR/logs"
OLLAMA_DIR="$BASE_DIR/ollama"
MODEL_STORE="$OLLAMA_DIR/models"
BUNDLES_DIR="$OLLAMA_DIR/bundles"

mkdir -p "$LOG_DIR" "$MODEL_STORE" "$BUNDLES_DIR"

timestamp() { date +"%Y%m%d-%H%M%S"; }
TS="$(timestamp)"
DIAG_FILE="$LOG_DIR/diagnostics-$TS.txt"
PLAN_FILE="$LOG_DIR/ai-plan-$TS.md"
ACTIONS_LOG="$LOG_DIR/actions-$TS.log"

note() { echo "[it-tool] $*"; }
warn() { echo "[it-tool][warn] $*"; }
err()  { echo "[it-tool][error] $*"; }

prompt_yes_no() {
  local msg="$1"
  local default="${2:-N}"
  local prompt="[y/N]"
  [[ "$default" =~ ^[Yy]$ ]] && prompt="[Y/n]"
  while true; do
    read -r -p "$msg $prompt " ans || { echo "$default"; return; }
    ans="${ans:-$default}"
    case "$ans" in
      [Yy]*) echo "Y"; return;;
      [Nn]*) echo "N"; return;;
    esac
  done
}

detect_ollama() {
  local bundled_bin1="$OLLAMA_DIR/Ollama.app/Contents/MacOS/ollama"
  local bundled_bin2="$OLLAMA_DIR/Ollama.app/Contents/MacOS/Ollama"
  if [[ -x "$bundled_bin1" ]]; then
    echo "$bundled_bin1"; return 0
  fi
  if [[ -x "$bundled_bin2" ]]; then
    echo "$bundled_bin2"; return 0
  fi
  if command -v ollama >/dev/null 2>&1; then
    command -v ollama; return 0
  fi
  echo "" # not found
}

start_ollama() {
  local ollama_bin="$1"
  note "Starting Ollama server (models at $MODEL_STORE)"
  OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" serve >"$LOG_DIR/ollama-serve.log" 2>&1 &
  local pid=$!

  # Wait until the server is responsive (up to 30 seconds)
  for i in {1..30}; do
    if OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" list >/dev/null 2>&1; then
      note "Ollama is ready."
      return 0
    fi
    sleep 1
  done
  note "Warning: Ollama did not report ready in time; continuing anyway."
}

import_bundles() {
  local ollama_bin="$1"
  shopt -s nullglob
  local bundles=("$BUNDLES_DIR"/*.ollama)
  if (( ${#bundles[@]} == 0 )); then
    return 0
  fi
  note "Importing model bundles (${#bundles[@]})"
  for f in "${bundles[@]}"; do
    note "Importing: $(basename "$f")"
    if ! OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" import "$f" >>"$LOG_DIR/ollama-import.log" 2>&1; then
      note "Import failed or model exists: $(basename "$f") (see logs/ollama-import.log)"
    fi
  done
}

pick_model() {
  local ollama_bin="$1"
  if [[ -n "${MODEL:-}" ]]; then
    echo "$MODEL"
    return 0
  fi

  # Try to pick the first model from `ollama list`
  local first_model
  first_model=$(OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" list 2>/dev/null | awk 'NR>1 {print $1; exit}') || true
  if [[ -n "$first_model" ]]; then
    echo "$first_model"
    return 0
  fi

  # Fallback to a sensible default tag (may not exist yet)
  echo "llama3.1:8b-instruct"
}

collect_section() {
  local title="$1"
  shift
  echo "## $title" >>"$DIAG_FILE"
  {
    "$@"
  } >>"$DIAG_FILE" 2>&1 || true
  echo -e "\n---\n" >>"$DIAG_FILE"
}

collect_diagnostics() {
  note "Collecting diagnostics → $DIAG_FILE"
  {
    echo "macOS IT Tool Diagnostics"
    echo "Timestamp: $(date -Is)"
    echo "Tool version: 0.1.0"
    echo
  } >"$DIAG_FILE"

  collect_section "OS Version" sw_vers
  collect_section "Kernel" uname -a
  collect_section "Uptime" uptime
  collect_section "Hardware" system_profiler SPHardwareDataType
  collect_section "Root Disk Usage" df -H /
  collect_section "Spotlight Indexing" mdutil -s /
  collect_section "Network Interfaces" ifconfig -a
  collect_section "DNS Summary" sh -c 'scutil --dns | sed -n "1,120p"'
  collect_section "Default Route" route -n get default
  collect_section "Wi-Fi (if present)" sh -c 'networksetup -listallhardwareports; echo; networksetup -getinfo Wi-Fi || true'
  collect_section "Recent Reboots" last reboot | head -n 10
  collect_section "Login Items" osascript -e 'tell application "System Events" to get the name of every login item'
}

generate_ai_plan() {
  local ollama_bin="$1"
  local model_tag="$2"
  note "Generating AI remediation plan with model: $model_tag"

  local prompt
  prompt=$(cat <<'EOF'
You are a senior macOS IT support assistant. You are given raw diagnostics from a Mac.
Produce a concise, actionable audit and remediation plan tailored to these findings.

Constraints:
- Assume offline or limited connectivity. Prefer steps that do not require internet.
- Be safe-first: do not suggest destructive commands without backups/confirmation.
- Output only Markdown with the following sections:
  - Summary
  - Key Issues (bulleted)
  - Recommended Fixes (prioritized, with specific macOS commands where applicable)
  - Safe One-Liners (copy/paste commands)
  - Manual Steps (UI)
  - Risks & Rollbacks
  - Next Checks

Here are the diagnostics:
<<<DIAGNOSTICS>>>
EOF
)

  # Embed diagnostics
  prompt="${prompt/<<<DIAGNOSTICS>>>/$(sed 's/\/\\/g;s/`/\`/g' "$DIAG_FILE") }"

  if OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" list >/dev/null 2>&1; then
    if ! OLLAMA_MODELS="$MODEL_STORE" "$ollama_bin" run "$model_tag" -p "$prompt" >"$PLAN_FILE" 2>>"$LOG_DIR/ai-errors.log"; then
      note "AI generation failed (see logs/ai-errors.log)."
      return 1
    fi
    note "AI plan saved → $PLAN_FILE"
    return 0
  fi
  return 1
}

# ===== Remediation actions (safe-first) =====

log_action() { echo "[$(date -Is)] $*" | tee -a "$ACTIONS_LOG"; }

need_sudo() {
  if sudo -n true >/dev/null 2>&1; then return 0; fi
  note "Some actions need administrator rights."
  sudo -v || { warn "Admin rights not granted. Skipping privileged fixes."; return 1; }
}

primary_interface() {
  route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'
}

service_for_interface() {
  local ifc="$1"
  # Parse networksetup mapping of Hardware Port ↔ Device
  networksetup -listallhardwareports 2>/dev/null | awk -v ifc="$ifc" '
    /^Hardware Port:/{port=$0; sub(/^Hardware Port: /, "", port)}
    /^Device:/{dev=$2; if (dev==ifc){print port; exit}}
  '
}

act_flush_dns() {
  log_action "Flush DNS cache"
  need_sudo || return 0
  sudo dscacheutil -flushcache || true
  sudo killall -HUP mDNSResponder || true
}

act_restart_mdns() {
  log_action "Restart mDNSResponder"
  need_sudo || return 0
  sudo launchctl kickstart -k system/com.apple.mDNSResponder || true
}

act_rebuild_spotlight() {
  log_action "Rebuild Spotlight index for /"
  need_sudo || return 0
  sudo mdutil -E / || true
  sudo mdutil -i on / || true
}

act_ls_rebuild() {
  log_action "Rebuild Launch Services database"
  local LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  "$LSREG" -kill -r -domain local -domain system -domain user || true
}

act_verify_disk() {
  log_action "Verify system volume"
  diskutil verifyVolume / || true
}

act_renew_dhcp() {
  local ifc="$(primary_interface)"
  local svc="$(service_for_interface "$ifc")"
  if [[ -z "$svc" ]]; then
    warn "Could not map interface $ifc to a network service; skipping DHCP renew."
    return 0
  fi
  log_action "Renew DHCP lease for service: $svc (iface $ifc)"
  networksetup -setdhcp "$svc" || true
}

act_bounce_iface() {
  local ifc="$(primary_interface)"
  if [[ -z "$ifc" ]]; then
    warn "No primary interface detected; skipping interface bounce."
    return 0
  fi
  log_action "Bounce interface $ifc (down/up)"
  need_sudo || return 0
  sudo ifconfig "$ifc" down || true
  sleep 2
  sudo ifconfig "$ifc" up || true
}

show_actions_menu() {
  cat <<EOF
Safe Remediation Actions (enter numbers separated by commas):
  1) Flush DNS cache (dscacheutil + mDNSResponder)
  2) Restart mDNSResponder service
  3) Renew DHCP on active service
  4) Bounce active network interface (down/up)
  5) Rebuild Spotlight index for /
  6) Rebuild Launch Services database
  7) Verify system volume (read-only)
  0) Cancel
EOF
}

run_selected_actions() {
  local selection="$1"
  IFS=',' read -r -a picks <<<"$selection"
  for pick in "${picks[@]}"; do
    pick="${pick//[[:space:]]/}"
    case "$pick" in
      1) act_flush_dns;;
      2) act_restart_mdns;;
      3) act_renew_dhcp;;
      4) act_bounce_iface;;
      5) act_rebuild_spotlight;;
      6) act_ls_rebuild;;
      7) act_verify_disk;;
      0) note "Cancelled by user"; return 0;;
      "") ;;
      *) warn "Unknown choice: $pick";;
    esac
  done
}

main() {
  note "Starting macOS IT tool"
  local ollama_bin
  ollama_bin=$(detect_ollama)
  if [[ -z "$ollama_bin" ]]; then
    note "Ollama not found. Place Ollama.app at: $OLLAMA_DIR or install system-wide."
    note "Skipping AI step; running diagnostics only."
    collect_diagnostics
    open "$DIAG_FILE" || true
    exit 0
  fi

  start_ollama "$ollama_bin" || true
  import_bundles "$ollama_bin" || true

  collect_diagnostics

  local model_tag
  model_tag=$(pick_model "$ollama_bin")

  if generate_ai_plan "$ollama_bin" "$model_tag"; then
    # Show the plan by default
    open "$PLAN_FILE" || true
  else
    note "No model available or AI step failed; opening diagnostics instead."
    open "$DIAG_FILE" || true
  fi

  echo
  if [[ "${AUTO_APPLY_SAFE:-}" == "1" ]]; then
    note "AUTO_APPLY_SAFE=1 set; applying recommended safe actions: 1,2,3"
    run_selected_actions "1,2,3"
    note "Actions log → $ACTIONS_LOG"
    exit 0
  fi

  if [[ "$(prompt_yes_no "Apply selected safe fixes now?" N)" == "Y" ]]; then
    show_actions_menu
    read -r -p "Select actions (e.g., 1,3,5) > " picks
    run_selected_actions "$picks"
    note "Actions complete. Log → $ACTIONS_LOG"
  else
    note "Audit-only mode; no changes applied."
  fi
}

main "$@"
