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
mkdir -p "$PKG_DIR/.APP"
cp -R "$APP_NAME" "$PKG_DIR/.APP/"

# Use existing install.command or installer/install.sh or root install.sh when available, else fallback to embedded default.
if [ -f "./install.command" ]; then
  cp "./install.command" "$PKG_DIR/install.command"
elif [ -f "./installer/install.sh" ]; then
  cp "./installer/install.sh" "$PKG_DIR/install.command"
elif [ -f "./install.sh" ]; then
  cp "./install.sh" "$PKG_DIR/install.command"
else
  cat > "$PKG_DIR/install.command" <<'SH'
#!/bin/bash
set -euo pipefail

APP="NativeTouch.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SRC="$SCRIPT_DIR/.APP/$APP"
DEST="/Applications/$APP"

# fallback to root for flexibility
if [ ! -d "$SRC" ]; then
  SRC="$SCRIPT_DIR/$APP"
fi

if [ ! -d "$SRC" ]; then
  echo "ERROR: $SRC not found. Run this script from the folder containing NativeTouch.app."
  exit 1
fi

if [ -d "$DEST" ]; then
  echo "Updating existing $DEST"
  rm -rf "$DEST"
fi

cp -R "$SRC" "$DEST"

xattr -cr "$DEST"

if command -v spctl >/dev/null 2>&1; then
  if spctl --status 2>&1 | grep -q "assessments disabled"; then
    :
  else
    if ! spctl --add "$DEST" 2>/dev/null; then
      echo "⚠️ Gatekeeper registration is unsupported on this macOS version."
    fi
  fi
fi

open "$DEST"

echo "✅ NativeTouch installed to /Applications, unquarantined, and opened."
SH
fi

# Apply the app icon to install.command (optional, requires Finder/GUI)
if command -v osascript >/dev/null 2>&1; then
  APP_ICON_PATH="$PKG_DIR/.APP/$APP_NAME/Contents/Resources/NativeTouch.icns"
  INSTALL_SCRIPT_PATH="$PKG_DIR/install.command"

  if [ -f "$APP_ICON_PATH" ] && [ -f "$INSTALL_SCRIPT_PATH" ]; then
    osascript <<EOF
try
  set sourceFile to POSIX file "$APP_ICON_PATH" as alias
  set destFile to POSIX file "$INSTALL_SCRIPT_PATH" as alias
  tell application "Finder"
    set the icon of destFile to the icon of sourceFile
  end tell
on error
  return
end try
EOF
  fi
fi

chmod +x "$PKG_DIR/install.command"

# 3) Zip (preserve resource forks/custom icons)
rm -f "$ZIP_NAME"
# Using ditto with --sequesterRsrc keeps macOS resource forks and Finder metadata.
ditto -c -k --sequesterRsrc "$PKG_DIR" "$ZIP_NAME"

# 4) Cleanup
rm -rf "$PKG_DIR"

echo "✅ Pack complete: $ZIP_NAME"
ls -lh "$ZIP_NAME"
