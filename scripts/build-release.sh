#!/bin/bash
set -e

VERSION=${1:-"1.0.0"}
ARCH=${2:-$(uname -m)}  # Accept arch as second arg, default to uname -m
APP_NAME="DropConvert"
APP_BUNDLE="$APP_NAME.app"

# SPM uses arch-specific build dir and names the bundle <Package>_<Target>.bundle
if [ "$ARCH" = "arm64" ]; then
  BUILD_DIR=".build/arm64-apple-macosx/release"
else
  BUILD_DIR=".build/x86_64-apple-macosx/release"
fi
BUNDLE_RESOURCES="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"

echo "Building $APP_NAME $VERSION for $ARCH..."

# Build release binary
swift build -c release --arch "$ARCH"

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist (update version)
BUILD_NUM=$(echo "$VERSION" | tr -d '.')
sed -e "s/1\.0\.0/$VERSION/g" -e "s/<string>1<\/string>/<string>$BUILD_NUM<\/string>/" \
    Info.plist > "$APP_BUNDLE/Contents/Info.plist"

# Copy resource bundle to app root (SPM accessor expects it next to Contents/)
if [ -d "$BUNDLE_RESOURCES" ]; then
    cp -r "$BUNDLE_RESOURCES" "$APP_BUNDLE/${APP_NAME}_${APP_NAME}.bundle"
else
    echo "Warning: resource bundle not found at $BUNDLE_RESOURCES"
fi

# Copy app icon
cp Sources/DropConvert/Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Created $APP_BUNDLE"

# Zip it
ZIP_NAME="${APP_NAME}-${VERSION}-${ARCH}.zip"
zip -r "$ZIP_NAME" "$APP_BUNDLE"
echo "Packaged as $ZIP_NAME"
