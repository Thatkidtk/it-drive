## IT Drive (macOS Toolkit)

A portable macOS troubleshooting toolkit you can run from an external drive. It collects diagnostics and offers safe, reversible fixes. No internet or installs required.

Quick Start

- Double‑click `it-tool/Start-macOS-Python.command`.
- It generates an HTML diagnostics report and offers safe fixes.
- Requires macOS `python3` (usually available; otherwise `xcode-select --install`).

Features

- Diagnostics report (HTML + text) with a color‑coded Health Summary.
- Safe fixes: DNS flush, restart mDNSResponder, renew DHCP, bounce interface, Spotlight reindex, Launch Services DB rebuild, disk verify (read‑only).
- All logs saved under `it-tool/logs/`.

Advanced (optional)

- A minimal app bundle: `it-tool/App/IT Drive.app` launches the Python tool in Terminal.
- Optional local AI workflow using Ollama remains scaffolded (not required).

Repository Layout

- `it-tool/`: The portable toolkit
  - `Start-macOS-Python.command`: Main launcher
  - `mac/pytool.py`: Python CLI (audit + fixes)
  - `logs/`: Reports and action logs
  - `App/IT Drive.app`: Simple macOS app wrapper

License

- Add a license if you plan to distribute widely.

Release

- Zip the `it-tool/` folder and publish under Releases.
- Users can download, unzip, then run `it-tool/App/IT Drive.app` or `it-tool/Start-macOS-Python.command`.
