#!/bin/bash
set -euo pipefail

APP_NAME="Звук [unofficial]"
SCHEME="YAMP"
PROJECT="YAMP.xcodeproj"
BUILD_DIR="build"
DMG_NAME="Zvuk-unofficial"

cd "$(dirname "$0")/.."

# ── Bump build number ────────────────────────────────────────────────────────
CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "==> Bumping build: $CURRENT_BUILD → $NEW_BUILD"
sed -i '' "s/CURRENT_PROJECT_VERSION: \"$CURRENT_BUILD\"/CURRENT_PROJECT_VERSION: \"$NEW_BUILD\"/" project.yml

echo "==> Regenerating Xcode project..."
xcodegen generate >/dev/null

echo "==> Cleaning..."
rm -rf "$BUILD_DIR"

echo "==> Building Release..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR/derived" \
    build

APP_PATH=$(find "$BUILD_DIR/derived" -name "YAMP.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: YAMP.app not found"
    exit 1
fi

echo "==> Found app: $APP_PATH"

# Prepare DMG staging
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"

cp -R "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating DMG..."
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
rm -f "$DMG_PATH"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "==> Done: $DMG_PATH"
echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"

echo "==> Opening DMG..."
open "$DMG_PATH"
