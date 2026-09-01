#!/bin/bash

set -euo pipefail

REPOSITORY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$REPOSITORY_DIR/AppBundle/Info.plist"
APP_NAME="seifert-it Security Reader"
EXECUTABLE_NAME="SeifertSecurityReader"
DIST_DIR="$REPOSITORY_DIR/dist"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/seifert-security-reader.XXXXXX")"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

cleanup() {
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

cd "$REPOSITORY_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$DIST_DIR"
ditto "$BIN_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
ditto "$INFO_PLIST" "$APP_DIR/Contents/Info.plist"
ditto "$REPOSITORY_DIR/AppBundle/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
ditto "$REPOSITORY_DIR/Sources/SeifertSecurityReader/Resources/Logo_seifert-it.jpg" "$APP_DIR/Contents/Resources/Logo_seifert-it.jpg"

xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

ARCHIVE="$DIST_DIR/seifert-it-Security-Reader-macOS-v$VERSION.zip"
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE"

codesign --verify --deep --strict "$APP_DIR"
echo "Erstellt: $ARCHIVE"
