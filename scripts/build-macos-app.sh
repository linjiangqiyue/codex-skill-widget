#!/bin/bash
set -euo pipefail
VERSION="${1:-0.2.0-beta}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/macos"
swift build -c release
APP="$ROOT/dist/CodexSkillHelper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/CodexSkillHelper "$APP/Contents/MacOS/CodexSkillHelper"
while IFS= read -r -d '' resource_bundle; do
  cp -R "$resource_bundle" "$APP/Contents/Resources/"
done < <(find -L .build -type d -name '*.bundle' -print0)
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CodexSkillHelper</string>
<key>CFBundleIdentifier</key><string>com.moboss.codex-skill-helper</string>
<key>CFBundleName</key><string>Codex Skill 中文助手</string>
<key>CFBundleDisplayName</key><string>Codex Skill 中文助手</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${VERSION}</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
ditto -c -k --keepParent "$APP" "$ROOT/dist/CodexSkillHelper-macOS-v${VERSION}.zip"
