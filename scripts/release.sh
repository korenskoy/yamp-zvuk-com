#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

# ── Extract version from Configuration/Version.xcconfig ──────────────────────
VERSION=$(grep '^MARKETING_VERSION' Configuration/Version.xcconfig | sed 's/.*=[[:space:]]*//')
TAG="v$VERSION"
DMG_NAME="Zvuk-unofficial-${VERSION}.dmg"

if [ -z "$VERSION" ]; then
    echo "Error: could not extract MARKETING_VERSION from Configuration/Version.xcconfig"
    exit 1
fi

echo "==> Version: $VERSION (tag: $TAG)"

# ── Check tag doesn't already exist ──────────────────────────────────────────
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: tag $TAG already exists"
    exit 1
fi

# ── Extract changelog for this version ───────────────────────────────────────
# Reads everything between "## v{VERSION}" and the next "## v" header
CHANGELOG=$(awk "/^## $TAG\$/{found=1; next} /^## v/{if(found) exit} found" CHANGELOG.md)

if [ -z "$CHANGELOG" ]; then
    echo "Error: no changelog entry found for $TAG in CHANGELOG.md"
    echo "       Add a section starting with '## $TAG' before releasing."
    exit 1
fi

# Trim leading/trailing blank lines
CHANGELOG=$(echo "$CHANGELOG" | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

# ── Get previous tag for Full Changelog link ─────────────────────────────────
PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
REMOTE_URL=$(git remote get-url origin | sed 's/\.git$//' | sed 's|git@github.com:|https://github.com/|')

if [ -n "$PREV_TAG" ]; then
    COMPARE_LINE="**Full Changelog**: ${REMOTE_URL}/compare/${PREV_TAG}...${TAG}"
else
    COMPARE_LINE="**Full Changelog**: ${REMOTE_URL}/commits/${TAG}"
fi

# ── Build release body ───────────────────────────────────────────────────────
BODY=$(printf '%s\n\n%s' "$CHANGELOG" "$COMPARE_LINE")

echo ""
echo "==> Release notes:"
echo "────────────────────────────────────────"
echo "$BODY"
echo "────────────────────────────────────────"
echo ""

# ── Confirm ──────────────────────────────────────────────────────────────────
read -rp "Proceed with release $TAG? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ── Build DMG ────────────────────────────────────────────────────────────────
echo "==> Building DMG..."
./scripts/build-dmg.sh

# build-dmg.sh уже создаёт версионированный DMG (build/Zvuk-unofficial-<version>.dmg)
DEST_DMG="build/$DMG_NAME"
if [ ! -f "$DEST_DMG" ]; then
    echo "Error: DMG not found after build: $DEST_DMG"
    exit 1
fi
echo "==> DMG: $DEST_DMG ($(du -h "$DEST_DMG" | cut -f1))"

# ── Create tag and push ─────────────────────────────────────────────────────
echo "==> Creating tag $TAG..."
git tag -a "$TAG" -m "Release $VERSION"
git push origin "$TAG"

# ── Create GitHub release with DMG ───────────────────────────────────────────
echo "==> Creating GitHub release..."
gh release create "$TAG" \
    --title "$TAG" \
    --notes "$BODY" \
    "$DEST_DMG"

RELEASE_URL="${REMOTE_URL}/releases/tag/${TAG}"
echo ""
echo "==> Release published: $RELEASE_URL"
