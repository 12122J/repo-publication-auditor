#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT="RepoAuditorApp"
APP_NAME="Repo Auditor"
BUNDLE_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
EXECUTABLE="$BUNDLE_DIR/Contents/MacOS/$PRODUCT"

cd "$ROOT_DIR"

if pgrep -x "$PRODUCT" >/dev/null 2>&1; then
  pkill -x "$PRODUCT"
fi

swift build --product "$PRODUCT"
BIN_DIR="$(swift build --show-bin-path)"

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"

cp "$BIN_DIR/$PRODUCT" "$EXECUTABLE"
chmod +x "$EXECUTABLE"

cat > "$BUNDLE_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT</string>
  <key>CFBundleIdentifier</key>
  <string>dev.fjgbu.repo-auditor</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/open -n "$BUNDLE_DIR"

if [[ "${1:-}" == "--verify" ]]; then
  sleep 1
  pgrep -x "$PRODUCT" >/dev/null
  echo "Verified $PRODUCT is running"
fi
