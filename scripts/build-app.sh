#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/NetSwitch.app"
EXECUTABLE="$ROOT_DIR/.build/release/NetSwitch"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/NetSwitch"
cp "$ROOT_DIR/support/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "Built $APP_DIR"
