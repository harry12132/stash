#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/Stash.app"
STAGING="$ROOT/.build/Stash.app.staging"
ICON_SOURCE="$ROOT/Packaging/AppIcon.icns"
swift build -c release
BIN_DIR="$(cd "$ROOT" && swift build -c release --show-bin-path)"
ICON_SOURCE="$ROOT/Packaging/AppIcon.icns"

if [[ -e "$STAGING" ]]; then
    printf 'Build staging bundle already exists: %s\n' "$STAGING" >&2
    exit 1
fi

if [[ ! -f "$ROOT/Sources/Stash_macOS26_Source/Resources/StashLogo.png" ]]; then
    printf 'App logo not found in Sources/Stash_macOS26_Source/Resources.\n' >&2
    exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
    printf 'App icon not found: %s\n' "$ICON_SOURCE" >&2
    exit 1
fi

mkdir -p "$STAGING/Contents/MacOS" "$STAGING/Contents/Resources"
cp "$BIN_DIR/Stash" "$STAGING/Contents/MacOS/Stash"
cp "$ROOT/Packaging/Info.plist" "$STAGING/Contents/Info.plist"
cp "$ROOT/Sources/Stash_macOS26_Source/Resources/StashLogo.png" "$STAGING/Contents/Resources/StashLogo.png"
cp "$ICON_SOURCE" "$STAGING/Contents/Resources/AppIcon.icns"
codesign --force --deep --identifier com.harry.Stash \
    --requirements '=designated => identifier "com.harry.Stash"' \
    --sign - "$STAGING"
codesign --verify --deep --strict "$STAGING"

if [[ -e "$APP" ]]; then
    mv "$APP" "$ROOT/.build/Stash.app.previous.$(date +%s)"
fi
mv "$STAGING" "$APP"
codesign --verify --deep --strict "$APP"

printf 'Built app: %s\n' "$APP"
