#!/bin/bash
set -euo pipefail

# release.sh
# 1) Run pack.sh to generate NativeTouch.zip
# 2) Create a GitHub draft release with that zip as an asset

if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) is required. Install from https://github.com/cli/cli"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$SCRIPT_DIR"

echo "📦 Running pack.sh..."
./pack.sh

ASSET="NativeTouch.zip"
if [ ! -f "$ASSET" ]; then
    echo "❌ Expected asset not found: $ASSET"
    exit 1
fi

if [ $# -gt 0 ]; then
    TAG="$1"
else
    # default tag: version-style based on build.sh config (e.g., v1.0.1)
    VERSION="Unknown"
    if grep -q "CFBUNDLE_SHORT_VERSION" build.sh; then
        VERSION=$(grep -E '^CFBUNDLE_SHORT_VERSION' build.sh | cut -d'=' -f2 | tr -d '"')
    fi
    if [ "$VERSION" = "Unknown" ] || [ -z "$VERSION" ]; then
        echo "⚠️  Could not detect version from build.sh; using fallback tag v0.0.0"
        TAG="v0.0.0"
    else
        TAG="v${VERSION}"
    fi
fi

RELEASE_NAME="NativeTouch ${TAG}"
RELEASE_BODY="

- Includes: NativeTouch.zip (installer bundle + app)
- Build: $(date -u +'%Y-%m-%d %H:%M:%S UTC')
- Tag: ${TAG}
"
# If release already exists, remove it first to avoid gh errors (optional)
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "⚠️ Release $TAG already exists. Updating asset in existing draft/release."
    # Upload asset to existing release (overwrite by deleting first)
    EXISTING_ASSET_IDS=$(gh release view "$TAG" --json assets --jq '.assets[].id')
    if [ -n "$EXISTING_ASSET_IDS" ]; then
        echo "$EXISTING_ASSET_IDS" | while read -r asset_id; do
            gh api --method DELETE "/repos/{owner}/{repo}/releases/assets/$asset_id" >/dev/null 2>&1 || true
        done
    fi
    gh release upload "$TAG" "$ASSET" --clobber
else
    echo "🏷️ Creating draft release $TAG..."
    gh release create "$TAG" "$ASSET" --draft --title "$RELEASE_NAME" --notes "$RELEASE_BODY"
fi

echo "✅ Draft release ready: $TAG (asset attached: $ASSET)"
