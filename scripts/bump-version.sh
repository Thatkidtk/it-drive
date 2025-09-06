#!/bin/bash
# Usage: scripts/bump-version.sh vX.Y.Z "Summary of changes for CHANGELOG"
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
NEW_VER="${1:-}"        # e.g., v1.0.1
SUMMARY="${2:-}"        # one-line summary for CHANGELOG (optional)

if [[ -z "$NEW_VER" || ! "$NEW_VER" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Provide semver tag like v1.0.1" >&2
  exit 1
fi

SHORT_VER="${NEW_VER#v}"

echo "$NEW_VER" > "$ROOT_DIR/VERSION"

# Update app bundle Info.plist CFBundleShortVersionString (if present)
PLIST="$ROOT_DIR/it-tool/App/IT Drive.app/Contents/Info.plist"
if [[ -f "$PLIST" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VER" "$PLIST" 2>/dev/null || true
  # Fallback sed approach
  if ! grep -q "$SHORT_VER" "$PLIST"; then
    sed -i '' "s#<key>CFBundleShortVersionString</key>\n\t<string>[^<]*</string>#<key>CFBundleShortVersionString</key>\n\t<string>$SHORT_VER</string>#" "$PLIST" || true
  fi
fi

# Prepend CHANGELOG entry under [Unreleased]
CHANGELOG="$ROOT_DIR/CHANGELOG.md"
DATE="$(date +%Y-%m-%d)"
TMP_CHG="$(mktemp)"
if [[ -f "$CHANGELOG" ]]; then
  awk -v ver="$NEW_VER" -v dt="$DATE" -v summary="$SUMMARY" '
    BEGIN { done=0 }
    /^### \[Unreleased\]/ && !done {
      print;
      print "";
      print "### [" ver "] - " dt;
      if (length(summary)>0) print "- " summary; 
      print "";
      done=1;
      next
    }
    { print }
  ' "$CHANGELOG" > "$TMP_CHG" && mv "$TMP_CHG" "$CHANGELOG"
fi

cd "$ROOT_DIR"
git add VERSION "$PLIST" "$CHANGELOG" 2>/dev/null || true
git commit -m "chore: bump version to $NEW_VER" || true
git tag "$NEW_VER" -m "Release $NEW_VER" || true

echo "Bumped to $NEW_VER. To push: git push && git push origin $NEW_VER"

