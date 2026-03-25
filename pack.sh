#!/bin/bash
set -euo pipefail

APP_NAME="NativeTouch.app"
ZIP_NAME="NativeTouch.zip"
PKG_DIR="pack-temp"

# 1) Build
printf "🛠 Running build.sh\n"
./build.sh

if [ ! -d "$APP_NAME" ]; then
  printf "❌ Build output %s not found.\n" "$APP_NAME"
  exit 1
fi

# 2) Create package
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"
cp -R "$APP_NAME" "$PKG_DIR/"

if [ -f "installer/README.md" ]; then
  cp "installer/README.md" "$PKG_DIR/"
else
  echo "⚠️ installer/README.md not found; continuing without it."
fi

# 3) Zip (preserve resource forks/custom icons)
rm -f "$ZIP_NAME"
# Using ditto with --sequesterRsrc keeps macOS resource forks and Finder metadata.
ditto -c -k --sequesterRsrc "$PKG_DIR" "$ZIP_NAME"

# 4) Cleanup
rm -rf "$PKG_DIR"

echo "✅ Pack complete: $ZIP_NAME"
ls -lh "$ZIP_NAME"
