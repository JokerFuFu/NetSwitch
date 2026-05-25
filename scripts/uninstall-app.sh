#!/usr/bin/env bash
set -euo pipefail

INSTALLED_APP="$HOME/Applications/NetSwitch.app"
PLIST="$HOME/Library/LaunchAgents/com.joker2.netswitch.plist"
UID_VALUE="$(id -u)"

launchctl bootout "gui/$UID_VALUE" "$PLIST" 2>/dev/null || true
pkill -x NetSwitch 2>/dev/null || true
rm -rf "$INSTALLED_APP" "$PLIST"

echo "Removed NetSwitch app and login item"
