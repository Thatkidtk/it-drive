## Release Checklist

1) Build the zip locally (optional)

- From the parent of `it-drive/`:
  - `bash it-drive/scripts/build-zip.sh v1.0.0`
  - Produces `it-drive-v1.0.0.zip` (contains `it-tool/`)

2) Tag and push

- In `it-drive/` repo root:
  - `git tag v1.0.0`
  - `git push origin v1.0.0`

3) GitHub Actions creates the Release

- The workflow `.github/workflows/release.yml` zips `it-tool/` and attaches it as `it-drive-<tag>.zip` and also `it-drive-latest.zip` for a stable download link.

4) (Alternative) Manual release with GitHub CLI

- Build zip (step 1), then run in repo root:
  - `gh release create v1.0.0 ./it-drive-v1.0.0.zip -t "IT Drive v1.0.0" -n "Initial release with Python toolkit (audit + safe fixes)." --latest`

5) Verify

- Download the asset from the Release page.
- Unzip and double‑click `it-tool/App/IT Drive.app` or `it-tool/Start-macOS-Python.command`.
