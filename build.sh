#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Realme Buds Controller"
BUNDLE_DIR="$APP_NAME.app"
DIST_DIR="$SCRIPT_DIR/dist"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS="$SCRIPT_DIR/Resources/RealmeBudsController.entitlements"

echo "==> Building executable with SwiftPM (release mode)..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/RealmeBudsController"

echo "==> Packaging $BUNDLE_DIR..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/RealmeBudsController"
cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$SCRIPT_DIR/Sources/RealmeBudsController/Resources/BudsAir7CaseOpen.png" "$RESOURCES_DIR/BudsAir7CaseOpen.png"
cp "$SCRIPT_DIR/Sources/RealmeBudsController/Resources/BudsAir7Left.png" "$RESOURCES_DIR/BudsAir7Left.png"
cp "$SCRIPT_DIR/Sources/RealmeBudsController/Resources/BudsAir7Right.png" "$RESOURCES_DIR/BudsAir7Right.png"

SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/^ *[0-9][0-9]*).*\"\\(Developer ID Application:.*\\)\"$/\\1/p' \
        | head -n 1)"
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "==> Signing with Developer ID: $SIGNING_IDENTITY"
    codesign --force --deep --options runtime --timestamp \
        --sign "$SIGNING_IDENTITY" \
        --identifier "com.mubtasin.RealmeBudsController" \
        --entitlements "$ENTITLEMENTS" \
        "$BUNDLE_DIR"
    SIGNING_MODE="Developer ID"
else
    echo "==> No Developer ID identity found; using ad-hoc signing for local testing..."
    codesign --force --sign - \
        --identifier "com.mubtasin.RealmeBudsController" \
        --entitlements "$ENTITLEMENTS" \
        "$BUNDLE_DIR"
    SIGNING_MODE="Ad-hoc"
fi

codesign --verify --deep --strict "$BUNDLE_DIR"
codesign --display --verbose=2 "$BUNDLE_DIR" 2>&1 | sed -n '1,20p'

echo "==> Creating clean DMG install layout..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "$BUNDLE_DIR" "$DIST_DIR/$BUNDLE_DIR"

STAGING_DIR="$(mktemp -d)"
cp -R "$DIST_DIR/$BUNDLE_DIR" "$STAGING_DIR/$BUNDLE_DIR"
ln -s /Applications "$STAGING_DIR/Applications"
DMG_TEMP="$DIST_DIR/Realme Buds Controller.tmp.dmg"
DMG_OUTPUT="$DIST_DIR/Realme Buds Controller.dmg"
rm -f "$DMG_TEMP" "$DMG_OUTPUT"
hdiutil create -volname "Realme Buds Controller" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_OUTPUT"
rm -rf "$STAGING_DIR"

cat > "$DIST_DIR/README.md" <<'README_EOF'
# Realme Buds Controller

## Installation

Open `Realme Buds Controller.dmg`, then drag
`Realme Buds Controller.app` into the Applications folder.

## Signing status

The app in this build was signed with: **__SIGNING_MODE__**.

This build is not notarized. No notarization has been claimed or performed.

An ad-hoc signed app is not suitable for distribution to other Macs.
It must be installed and opened on the Mac used for local testing.

No notarization claim is made unless notarization is separately performed and
recorded by the distributor.

## Developer ID and notarization

For distribution to other Macs:

1. Install an Apple Developer "Developer ID Application" certificate.
2. Set `SIGNING_IDENTITY` to that exact identity when running `build.sh`.
3. Submit the resulting DMG or app with `notarytool`:
   `xcrun notarytool submit "dist/Realme Buds Controller.dmg" --apple-id ... --team-id ... --password ... --wait`
4. Staple the ticket:
   `xcrun stapler staple "dist/Realme Buds Controller.dmg"`
   `xcrun stapler staple "dist/Realme Buds Controller.app"`
5. Verify:
   `spctl -a -t exec -vv "dist/Realme Buds Controller.app"`
   `spctl -a -t open --context context:primary-signature -vv "dist/Realme Buds Controller.dmg"`

## Bluetooth permission

On first launch, macOS may ask for Bluetooth access. Approve it in:

System Settings > Privacy & Security > Bluetooth

## Preferences

User preferences are stored under:

`~/Library/Application Support/Realme Buds Controller/preferences.json`

This location persists across app upgrades. Appearance preferences are
also stored in the application-support preference file and retain legacy
UserDefaults compatibility.

## Runtime dependencies

The app is a native macOS executable. It does not require Xcode, VS Code,
Copilot, SwiftPM, or the development-folder resource paths at runtime.

Product resources are included inside the application bundle.
README_EOF

sed -i '' "s/__SIGNING_MODE__/$SIGNING_MODE/g" "$DIST_DIR/README.md"

echo "==> Verifying release artifacts..."
codesign --verify --deep --strict "$DIST_DIR/$BUNDLE_DIR"
hdiutil verify "$DMG_OUTPUT" >/dev/null

CLEAN_DIR="$(mktemp -d)"
cp -R "$DIST_DIR/$BUNDLE_DIR" "$CLEAN_DIR/$BUNDLE_DIR"
"$CLEAN_DIR/$BUNDLE_DIR/Contents/MacOS/RealmeBudsController" --show-popover >/dev/null 2>&1 &
CLEAN_PID=$!
sleep 3
if kill -0 "$CLEAN_PID" 2>/dev/null; then
    echo "==> Clean-copy launch check passed (PID $CLEAN_PID)"
else
    echo "==> Clean-copy launch check: process exited before verification"
fi
kill "$CLEAN_PID" 2>/dev/null || true
rm -rf "$CLEAN_DIR"

echo "==> Signing mode: $SIGNING_MODE"
echo "==> Release artifacts:"
echo "    $DIST_DIR/$BUNDLE_DIR"
echo "    $DIST_DIR/Realme Buds Controller.dmg"
echo "    $DIST_DIR/README.md"
