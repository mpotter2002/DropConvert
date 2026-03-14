#!/bin/bash
set -e

VERSION=${1:-"1.0.0"}
ARCH=$(uname -m)  # arm64 or x86_64
BUILD_DIR=".build/release"
APP_NAME="DropConvert"
APP_BUNDLE="$APP_NAME.app"
BUNDLE_RESOURCES="$BUILD_DIR/$APP_NAME.bundle"

echo "Building $APP_NAME $VERSION for $ARCH..."

# Build release binary
swift build -c release --arch "$ARCH"

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist (update version)
sed "s/1.0.0/$VERSION/g; s/<string>1<\/string>/<string>$(echo $VERSION | tr -d '.')/<\/string>/" \
    Info.plist > "$APP_BUNDLE/Contents/Info.plist"

# Copy bundled resources (menubar icon etc.)
if [ -d "$BUNDLE_RESOURCES" ]; then
    cp -r "$BUNDLE_RESOURCES/"* "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

echo "Created $APP_BUNDLE"

# Zip it
ZIP_NAME="${APP_NAME}-${VERSION}-${ARCH}.zip"
zip -r "$ZIP_NAME" "$APP_BUNDLE"
echo "Packaged as $ZIP_NAME"
