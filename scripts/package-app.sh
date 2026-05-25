#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/netswitch-package.XXXXXX")"
APP_DIR="$WORK_DIR/NetSwitch.app"
FINAL_APP_DIR="$DIST_DIR/NetSwitch.app"
PAYLOAD_DIR="$WORK_DIR/payload"
SCRIPTS_DIR="$WORK_DIR/scripts"
INFO_PLIST="$ROOT_DIR/support/Info.plist"
PLIST_BUDDY="/usr/libexec/PlistBuddy"
VERSION="$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
IDENTIFIER="$("$PLIST_BUDDY" -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
LAUNCH_AGENT_ID="$IDENTIFIER"
LAUNCH_AGENT_PLIST="$PAYLOAD_DIR/Library/LaunchAgents/$LAUNCH_AGENT_ID.plist"

trap 'rm -rf "$WORK_DIR"' EXIT

build_arch() {
	local triple="$1"
	swift build -c release --triple "$triple"
}

copy_bundle() {
	local executable="$1"

	rm -rf "$APP_DIR"
	mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
	cp "$executable" "$APP_DIR/Contents/MacOS/NetSwitch"
	cp "$INFO_PLIST" "$APP_DIR/Contents/Info.plist"
	chmod +x "$APP_DIR/Contents/MacOS/NetSwitch"
}

clean_macos_metadata() {
	local path="$1"
	xattr -cr "$path" 2>/dev/null || true
	find "$path" -name '.DS_Store' -delete
	find "$path" -name '._*' -delete
}

cd "$ROOT_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

build_arch "arm64-apple-macosx13.0"
build_arch "x86_64-apple-macosx13.0"

ARM64_EXE="$ROOT_DIR/.build/arm64-apple-macosx/release/NetSwitch"
X86_64_EXE="$ROOT_DIR/.build/x86_64-apple-macosx/release/NetSwitch"
UNIVERSAL_EXE="$WORK_DIR/NetSwitch"

lipo -create "$ARM64_EXE" "$X86_64_EXE" -output "$UNIVERSAL_EXE"
copy_bundle "$UNIVERSAL_EXE"
clean_macos_metadata "$APP_DIR"

codesign --force --deep --sign - "$APP_DIR"
clean_macos_metadata "$APP_DIR"

ditto -c -k --keepParent "$APP_DIR" "$DIST_DIR/NetSwitch-$VERSION-universal.zip"
ditto --norsrc "$APP_DIR" "$FINAL_APP_DIR"

mkdir -p "$PAYLOAD_DIR/Applications" "$PAYLOAD_DIR/Library/LaunchAgents" "$SCRIPTS_DIR"
ditto --norsrc "$APP_DIR" "$PAYLOAD_DIR/Applications/NetSwitch.app"

cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LAUNCH_AGENT_ID</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>-a</string>
		<string>/Applications/NetSwitch.app</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
</dict>
</plist>
PLIST

cat > "$SCRIPTS_DIR/postinstall" <<'POSTINSTALL'
#!/usr/bin/env bash
set -euo pipefail

CONSOLE_USER="$(stat -f '%Su' /dev/console)"
if [[ "$CONSOLE_USER" != "root" ]]; then
	USER_ID="$(id -u "$CONSOLE_USER")"
	PLIST="/Library/LaunchAgents/com.joker2.netswitch.plist"
	launchctl bootout "gui/$USER_ID" "$PLIST" 2>/dev/null || true
	launchctl bootstrap "gui/$USER_ID" "$PLIST" 2>/dev/null || true
	launchctl kickstart -k "gui/$USER_ID/com.joker2.netswitch" 2>/dev/null || true
fi

exit 0
POSTINSTALL
chmod +x "$SCRIPTS_DIR/postinstall"
clean_macos_metadata "$PAYLOAD_DIR"

pkgbuild \
	--root "$PAYLOAD_DIR" \
	--scripts "$SCRIPTS_DIR" \
	--filter '\.DS_Store$' \
	--filter '/\._[^/]*$' \
	--filter '^\._[^/]*$' \
	--identifier "$IDENTIFIER" \
	--version "$VERSION" \
	--install-location "/" \
	"$DIST_DIR/NetSwitch-$VERSION-universal.pkg"

echo "Created:"
echo "  $FINAL_APP_DIR"
echo "  $DIST_DIR/NetSwitch-$VERSION-universal.zip"
echo "  $DIST_DIR/NetSwitch-$VERSION-universal.pkg"
