#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Stash.app"
BUILD_DIR="$ROOT/.build"
mkdir -p "$BUILD_DIR"
STAGING="$(mktemp -d "$BUILD_DIR/dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

if [[ ! -d "$APP" ]]; then
    printf 'App bundle not found. Run ./build-app.sh first.\n' >&2
    exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
    printf 'create-dmg is required. Install it with: brew install create-dmg\n' >&2
    exit 1
fi

mkdir -p "$STAGING/root"
cp -R "$APP" "$STAGING/root/Stash.app"
swift "$ROOT/Packaging/create-dmg-background.swift" "$STAGING/background.png"

create-dmg \
    --volname "Stash" \
    --window-pos 160 120 \
    --window-size 800 500 \
    --icon-size 144 \
    --icon "Stash.app" 190 280 \
    --app-drop-link 610 280 \
    --hide-extension "Stash.app" \
    --background "$STAGING/background.png" \
    "$STAGING/Stash.dmg" \
    "$STAGING/root"

mv -f "$STAGING/Stash.dmg" "$ROOT/Stash.dmg"
printf 'Built DMG: %s\n' "$ROOT/Stash.dmg"
