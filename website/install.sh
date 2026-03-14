#!/bin/bash
set -e

REPO="mpotter2002/DropConvert"
APP_NAME="DropConvert"
INSTALL_DIR="/Applications"

echo "Installing $APP_NAME..."

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  ASSET="DropConvert-arm64.zip"
else
  ASSET="DropConvert-x86_64.zip"
fi

# Get latest release download URL
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep "browser_download_url" \
  | grep "$ASSET" \
  | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: Could not find release asset for $ARCH."
  exit 1
fi

# Download and extract
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

echo "Downloading $ASSET..."
curl -fsSL "$DOWNLOAD_URL" -o "$TMP/$ASSET"
unzip -q "$TMP/$ASSET" -d "$TMP"

# Move to Applications
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi
mv "$TMP/$APP_NAME.app" "$INSTALL_DIR/"

# Strip quarantine so Gatekeeper doesn't block it
xattr -rd com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

echo ""
echo "$APP_NAME installed to $INSTALL_DIR/$APP_NAME.app"
echo "Launch it from Applications or run: open /Applications/$APP_NAME.app"
