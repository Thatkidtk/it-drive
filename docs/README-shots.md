## Capturing Screenshots & GIF

Use the helper scripts in `scripts/` to capture screenshots and build a simple animated GIF for the README.

1) Capture screenshots

- Run: `bash scripts/capture-screenshots.sh`
- It saves:
  - `docs/screens/01-it-tool-folder.png`
  - `docs/screens/02-terminal-running.png`
  - `docs/screens/03-html-report.png`
  - `docs/screens/04-safe-fixes.png`

2) Build the GIF

- Requires ImageMagick: `brew install imagemagick`
- Run: `bash scripts/make-gif.sh`
- Output: `docs/getting-started.gif`

3) Update README

- After generating the GIF, the README’s “Getting Started” section will show it automatically.

