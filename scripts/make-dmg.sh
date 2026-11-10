#!/bin/sh
# Builds a distribution DMG: .build/dist/DiskLED-plus-<version>.dmg
#
# Usage: scripts/make-dmg.sh [version] [identity]
#   version   — defaults to the latest CHANGELOG heading.
#   identity  — passed through to make-app.sh ("Developer ID" for the
#               notarizable build; omit for ad-hoc).
#
# Notarization runs when the notary keychain profile "diskledplus-notary"
# exists. When it does, the DMG is notarized and stapled; otherwise you get a
# warning (unsigned-dmg DMG acceptable only for local use — Gatekeeper blocks
# unsigned downloads on other machines).
set -eu

VERSION="${1:-$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '[]' | sed 's/^## //')}"
IDENTITY="${2:-}"
NOTARY_PROFILE="diskledplus-notary"
STAGING=".build/dmg-staging"
DMG=".build/dist/DiskLED-plus-${VERSION}.dmg"

scripts/make-app.sh "$VERSION" "$IDENTITY"

rm -rf "$STAGING"
mkdir -p "$STAGING" .build/dist
cp -R .build/app/DiskLED-plus.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "DiskLED-plus" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

# The DMG container itself is notarized (Apple best practice).
if [ -n "$IDENTITY" ]; then
    codesign --force --timestamp --sign "$IDENTITY" "$DMG"
fi

set +e
SUBMIT_OUTPUT="$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)"
SUBMIT_STATUS=$?
set -e
if [ $SUBMIT_STATUS -eq 0 ]; then
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    echo "Notarized + stapled: $DMG"
elif echo "$SUBMIT_OUTPUT" | grep -qi "keychain\|credential"; then
    echo "WARNING: notary keychain profile '$NOTARY_PROFILE' not found."
    echo "DMG built but NOT notarized: $DMG"
    echo "Gatekeeper will block this on machines other than the build host."
    echo "Run: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <your Apple ID> --password <app-specific password> --team-id <TEAMID>"
else
    echo "Notarization submit failed:"
    echo "$SUBMIT_OUTPUT"
    exit 1
fi
