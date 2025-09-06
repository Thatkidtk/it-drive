# macOS IT Tool (Portable, Offline-Friendly)

This folder turns your Samsung T7 into a plug-in macOS IT assistant that audits a machine and (optionally) uses a local Ollama model to propose fixes.

Quick start (Python-only mode):

1) Run the Python toolkit
   - Double‑click `it-tool/Start-macOS-Python.command` (or right‑click → Open).
   - It collects diagnostics to `it-tool/logs/` and offers safe fixes.
   - Requires macOS `python3` (usually present; otherwise install CLT with `xcode-select --install`).

2) Apply safe fixes (optional)
   - After the report, you’ll be prompted to run remediations.
   - Options: flush DNS, restart mDNSResponder, renew DHCP, bounce interface, rebuild Spotlight, rebuild Launch Services DB, verify disk.
   - Admin rights: You may be prompted for your password (sudo) for certain steps.

What gets created

- `logs/diagnostics-<timestamp>.txt`: System audit snapshot (no changes applied).
- `logs/py-diagnostics-<timestamp>.txt`: Python toolkit diagnostics report.
- `logs/py-diagnostics-<timestamp>.html`: HTML version with color-coded summary.
- `logs/py-actions-<timestamp>.log`: Log of any applied fixes via Python toolkit.

Customize

- Audit only: By default you can skip fixes and just review the report.
- Auto mode: Run a minimal safe set from Terminal with `python3 it-tool/mac/pytool.py fix --auto`.

Folder layout

- `it-tool/Start-macOS-Agent.command`: Clickable launcher for macOS.
- `it-tool/Import-Model.command`: Click to import a specific `.ollama` bundle.
- `it-tool/mac/agent.sh`: Orchestrator script.
- `it-tool/mac/import-model.sh`: Helper used by Import-Model.command.
- `it-tool/ollama/Ollama.app` (optional): Portable Ollama binary location.
- `it-tool/ollama/bundles/`: Put offline `.ollama` bundles here to auto-import.
- `it-tool/ollama/models/`: Model storage (kept on the SSD).
- `it-tool/logs/`: All run logs and reports.

Troubleshooting

- Gatekeeper: If macOS blocks the `.command`, right‑click → Open, then confirm.
- Admin prompts: If you skip the password, privileged fixes are skipped safely.
- Command not found: Some sections may be empty on older systems; that’s fine.

AI (optional, later)
- The AI/Ollama-based flow remains available via `Start-macOS-Agent.command` if/when you want to enable it again.

Distributable App Bundle
- A simple app bundle lives at `it-tool/App/IT Drive.app`.
- Double-click to open Terminal and run the Python launcher.
- Keep the app bundle inside the `it-tool/` folder so it can find `Start-macOS-Python.command`.

Share as a GitHub project
- Repo layout suggestion (example: https://github.com/Thatkidtk/it-drive):
  - `it-tool/` (this whole folder)
  - Add a top-level README that tells users to download the repo zip, then open `it-tool/App/IT Drive.app` or `it-tool/Start-macOS-Python.command`.
- Publishing steps:
  1) Create the repo on GitHub (or use `it-drive.git`).
  2) Copy the `it-tool/` folder into the repo and push.
  3) Create a release ZIP so others can download and run without Git.
  4) Optional: notarize the app for smoother Gatekeeper experience (requires Apple developer account).

Offline model guide

Export on an online Mac:
- Install Ollama and pull the models you want:
  - `ollama pull llama3.1:8b-instruct`
  - Optional: add others (e.g., `llama3.1:70b-instruct` if you have space)
- Export bundles to portable `.ollama` files:
  - `ollama export llama3.1:8b-instruct -o ~/Desktop/llama3.1-8b.ollama`
  - Repeat for any additional models.

Copy to this SSD:
- Place the `.ollama` files into `it-tool/ollama/bundles/` for auto-import on next run
  or use the importer for a specific file.

Import on the target Mac (offline):
- Easiest: double‑click `it-tool/Start-macOS-Agent.command` and it will auto‑import any `.ollama` files in `it-tool/ollama/bundles/`.
- Specific file: double‑click `it-tool/Import-Model.command` and choose the `.ollama` file when prompted.

Verify models are available:
- Run: `it-tool/Start-macOS-Agent.command` once; it prints the model list to `it-tool/logs/ollama-serve.log` and to Terminal.
- Or run: `OLLAMA_MODELS=it-tool/ollama/models <path to ollama> list`

Space notes:
- `llama3.1:8b` ~4.7 GB; `70b` is very large and typically not practical on most Macs without plenty of free space and RAM.
- Keep the `it-tool/ollama/models/` folder on the SSD to avoid using the internal disk.
