#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Realme Buds Controller"
BUNDLE_DIR="$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building executable with SwiftPM (release mode)..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/RealmeBudsController"

echo "==> Packaging $BUNDLE_DIR..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/RealmeBudsController"
cp Resources/Info.plist "$CONTENTS_DIR/Info.plist"

echo "==> Ad-hoc signing app bundle with stable identifier..."
codesign --force --sign - \
    --identifier "com.mubtasin.RealmeBudsController" \
    --entitlements Resources/RealmeBudsController.entitlements \
    "$BUNDLE_DIR"

echo "==> Successfully built and signed: $SCRIPT_DIR/$BUNDLE_DIR"
