## IT Drive (macOS Toolkit)

[![Latest Release](https://img.shields.io/github/v/release/Thatkidtk/it-drive?include_prereleases&label=release)](https://github.com/Thatkidtk/it-drive/releases)
[![Downloads](https://img.shields.io/github/downloads/Thatkidtk/it-drive/total)](https://github.com/Thatkidtk/it-drive/releases)
[![Build Release Zip](https://github.com/Thatkidtk/it-drive/actions/workflows/release.yml/badge.svg)](https://github.com/Thatkidtk/it-drive/actions/workflows/release.yml)

A portable macOS troubleshooting toolkit you can run from an external drive. It collects diagnostics and offers safe, reversible fixes. No internet or installs required.

Download Latest

- Direct asset (after first release):
  - https://github.com/Thatkidtk/it-drive/releases/latest/download/it-drive-latest.zip
  - Unzip, then run `it-tool/App/IT Drive.app` or `it-tool/Start-macOS-Python.command`.

Getting Started

- 1) Download and unzip the latest release.
- 2) Open `it-tool/Start-macOS-Python.command`.
- 3) Review the HTML diagnostics report that opens.
- 4) Optionally apply safe fixes in Terminal.

Preview

If present, you’ll see a short GIF here showing the flow:

![Getting Started](docs/getting-started.gif)

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


