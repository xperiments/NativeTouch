#!/bin/bash
set -euo pipefail

APP="NativeTouch.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SRC="$SCRIPT_DIR/.APP/$APP"
DEST="/Applications/$APP"

# fallback to root in case the installer is packaged differently
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

# spctl --add is deprecated / unsupported on newer macOS versions.
# If needed, user can add it manually, but avoid noisy errors.
if command -v spctl >/dev/null 2>&1; then
  if spctl --status 2>&1 | grep -q "assessments disabled"; then
    :
  else
    if ! spctl --add "$DEST" 2>/dev/null; then
      echo "⚠️ Note: Gatekeeper registration is not supported automatically on this macOS version."
    fi
  fi
fi

open "$DEST"

cat << 'EOF'
  _   _       _   _        _______               _     
 | \ | |     | | (_)      |__   __|             | |    
 |  \| | __ _| |_ ___   _____| | ___  _   _  ___| |__  
 | . ` |/ _` | __| \ \ / / _ \ |/ _ \| | | |/ __| '_ \ 
 | |\  | (_| | |_| |\ V /  __/ | (_) | |_| | (__| | | |
 |_| \_|\__,_|\__|_| \_/ \___|_|\___/ \__,_|\___|_| |_|
=======================================================


You can now close this installer.

⚠️  If macOS shows a warning about an
   unidentified developer:

   1. Open System Settings
   2. Go to Privacy & Security
   3. Click 'Open Anyway' for NativeTouch
   4. Launch it again from /Applications

========================================

EOF