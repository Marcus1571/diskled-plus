#!/bin/sh
# Builds .build/app/DiskLED-plus.app from a fresh release build.
#
# Usage: scripts/make-app.sh [version]
#   Version defaults to the most recent version heading in CHANGELOG.md.
#   Output is ad-hoc signed (no Developer ID on the build host — notarization
#   is parked until a Developer ID exists; see KB.md §Packaging).
#
#   Install: cp -R ".build/app/DiskLED-plus.app" /Applications/
set -eu

VERSION="${1:-$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '[]' | sed 's/^## //')}"
APP_DIR=".build/app/DiskLED-plus.app"
CONTENTS="$APP_DIR/Contents"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp .build/release/DiskLEDPlus "$CONTENTS/MacOS/DiskLEDPlus"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>DiskLED-plus</string>
	<key>CFBundleIdentifier</key>
	<string>com.diskledplus.app</string>
	<key>CFBundleExecutable</key>
	<string>DiskLEDPlus</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${VERSION}</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_DIR"

echo "Built $APP_DIR (version ${VERSION}, ad-hoc signed)"
echo "Install:  cp -R \"$APP_DIR\" /Applications/"
